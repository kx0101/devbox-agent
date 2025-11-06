using OpenAI;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using System.ComponentModel;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

var client = new OpenAIClient(Environment.GetEnvironmentVariable("OPENAI_KEY")) ?? throw new Exception("OpenAI client is not initialized.");

[Description("Explain what the given code does.")]
static string ExplainCode([Description("Code snippet to explain.")] string code)
    => $"Explain this code:\n{code}";

[Description("Run a quick syntax or style check on code.")]
static string LintCode([Description("Code snippet to lint.")] string code)
{
    return "Lint check: No major issues found.";
}

[Description("Generate a commit message given a diff or summary.")]
static string GenerateCommitMessage([Description("Code diff or summary.")] string diff)
{
    return $"Commit message: {diff[..Math.Min(diff.Length, 100)]}, the format should be <type>[optional scope]: <description>";
}

[Description("Summarize logs or stack traces.")]
static string SummarizeLogs([Description("The log content.")] string logs)
    => $"Summarize this log:\n{logs}";

AIAgent devbox = client
    .GetChatClient("gpt-4o-mini")
    .CreateAIAgent(
        instructions: """
        You are DevBox, a developer's assistant.
        Use the available tools to help with coding, debugging, and infra questions.
        """,
        name: "DevBox",
        tools: [
            AIFunctionFactory.Create(ExplainCode),
            AIFunctionFactory.Create(LintCode),
            AIFunctionFactory.Create(GenerateCommitMessage),
            AIFunctionFactory.Create(SummarizeLogs)
        ]
    );

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapPost("/ask", async (HttpContext context, DevBoxRequest req) =>
{
    context.Response.Headers.Append("Content-Type", "text/event-stream");
    context.Response.Headers.Append("Cache-Control", "no-cache");
    context.Response.Headers.Append("Connection", "keep-alive");

    var buffer = new System.Text.StringBuilder();
    const int FLUSH_THRESHOLD = 60;

    await foreach (var update in devbox.RunStreamingAsync(req.Message))
    {
        foreach (var content in update.Contents)
        {
            if (content is TextContent text)
            {
                buffer.Append(text.Text);

                if (buffer.Length >= FLUSH_THRESHOLD)
                {
                    await context.Response.WriteAsync($"{buffer}");
                    await context.Response.Body.FlushAsync();
                    buffer.Clear();
                }
            }
        }
    }

    if (buffer.Length > 0)
    {
        await context.Response.WriteAsync($"{buffer}\n\n");
        await context.Response.Body.FlushAsync();
        buffer.Clear();
    }

    await context.Response.WriteAsync("[DONE]\n\n");
    await context.Response.Body.FlushAsync();
});

app.Run("http://localhost:8080");

public record DevBoxRequest(string Message);
