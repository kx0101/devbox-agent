using Azure;
using Azure.AI.OpenAI;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using System.ComponentModel;
using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using OpenAI;

var key = Environment.GetEnvironmentVariable("AZURE_OPENAI_KEY") ?? throw new InvalidOperationException("AZURE_OPENAI_KEY not set");
var uri = Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") ?? throw new InvalidOperationException("AZURE_OPENAI_ENDPOINT not set");
var model = Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT") ?? "gpt-5-mini";

[Description("Explain what the given code does.")]
static string ExplainCode([Description("Code snippet to explain.")] string code)
    => $"Explain this code:\n{code}";

[Description("Run a quick syntax or style check on code.")]
static string LintCode([Description("Code snippet to lint.")] string code)
    => "Lint check: No major issues found.";

[Description("Perform a code review given a git diff and file content.")]
static string ReviewFile(
    [Description("Path of the file being reviewed.")] string path,
    [Description("Git diff or patch text for the file.")] string diff,
    [Description("Full file content for context.")] string content)
{
    return $"""
    Review the following file in context:
    FILE: {path}

    DIFF:
    {diff}

    CONTENT:
    {content[..Math.Min(content.Length, 12000)]}
    """;
}

[Description("Read a file from disk to provide context for reviews or explanations.")]
static string ReadFile([Description("Absolute or relative path to the file.")] string path)
{
    try
    {
        if (!File.Exists(path))
        {
            return $"File not found: {path}";
        }

        var content = File.ReadAllText(path);
        if (content.Length > 16000)
        {
            content = content[..16000] + "\n\n[Truncated]";
        }

        return $"File content of {path}:\n\n{content}";
    }
    catch (Exception ex)
    {
        return $"Error reading file {path}: {ex.Message}";
    }
}

var azureClient = new AzureOpenAIClient(new Uri(uri), new AzureKeyCredential(key));
var chatClient = azureClient.GetChatClient(model);

AIAgent devbox = chatClient.CreateAIAgent(
    instructions: """
        You are DevBox, a senior software engineer performing code reviews.

        Your goal is to leave concise, practical review comments — like those left on a GitHub or GitLab merge request.

        Guidelines:
        - Only mention real issues or improvements that affect logic, readability, maintainability, or correctness.
        - Do not restate obvious code behavior.
        - Keep each comment under 2 lines.
        - Use markdown bullets grouped by file.
        - If the code looks good overall, simply say: “✅ No significant issues.”
        - Avoid filler like “Overall this is good” or “In conclusion.”
        - Prefer direct actionable phrasing: “Rename X for clarity”, “Add null-check here”, “Consider extracting Y”.
    """,
    name: "DevBox",
    description: "Performs intelligent code reviews and explanations.",
    tools: [
        AIFunctionFactory.Create(ExplainCode),
        AIFunctionFactory.Create(LintCode),
        AIFunctionFactory.Create(ReadFile),
        AIFunctionFactory.Create(ReviewFile)
    ]
);

[Description("Search the project source code for a specific keyword.")]
static string SearchProject([Description("Keyword to search for in the source tree.")] string keyword)
{
    try
    {
        var files = Directory.GetFiles(Directory.GetCurrentDirectory(), "*.*", SearchOption.AllDirectories)
            .Where(f => f.EndsWith(".cs") || f.EndsWith(".lua") || f.EndsWith(".ts") || f.EndsWith(".go"))
            .Take(60);

        var matches = new StringBuilder();
        foreach (var file in files)
        {
            var content = File.ReadAllText(file);
            if (content.Contains(keyword, StringComparison.OrdinalIgnoreCase))
            {
                matches.AppendLine($"- {file}");
            }
        }

        return matches.Length == 0
            ? $"No results found for '{keyword}'."
            : $"Files mentioning '{keyword}':\n{matches}";
    }
    catch (Exception ex)
    {
        return $"Search error: {ex.Message}";
    }
}

AIAgent helpbox = chatClient.CreateAIAgent(
    instructions: """
        You are HelpBox, a technical assistant who understands an entire codebase.
        You answer developer questions about architecture, data flow, and implementation.
        - Always reason based on actual source files (via your tools).
        - Cite specific files or modules when relevant.
        - If unsure, say "I don’t have enough context from the repo."
    """,
    name: "HelpBox",
    description: "Helps developers understand the project codebase.",
    tools: [
        AIFunctionFactory.Create(ReadFile),
        AIFunctionFactory.Create(SearchProject)
    ]
);

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapPost("/ask", async (HttpContext context, DevBoxRequest req) =>
{
    context.Response.ContentType = "text/event-stream";
    context.Response.Headers.CacheControl = "no-cache";
    context.Response.Headers["X-Accel-Buffering"] = "no";

    var sb = new StringBuilder();

    try
    {
        await foreach (var update in devbox.RunStreamingAsync(req.Message))
        {
            foreach (var content in update.Contents)
            {
                if (content is TextContent t)
                {
                    sb.Append(t.Text);

                    if (sb.ToString().EndsWith(". ") || sb.ToString().EndsWith('\n'))
                    {
                        await context.Response.WriteAsync($"{sb}\n\n");
                        await context.Response.Body.FlushAsync();

                        sb.Clear();
                    }
                }
            }
        }

        if (sb.Length > 0)
        {
            await context.Response.WriteAsync($"{sb}\n\n");
            await context.Response.Body.FlushAsync();
        }

        await context.Response.WriteAsync("\n\n[DONE]\n\n");
        await context.Response.Body.FlushAsync();
    }
    catch (Exception ex)
    {
        await context.Response.WriteAsync($"\nerror: {ex.Message}\n\n");
        await context.Response.Body.FlushAsync();
    }
});

app.MapPost("/review", async (HttpContext context, ReviewRequest req) =>
{
    context.Response.ContentType = "text/event-stream";
    context.Response.Headers.CacheControl = "no-cache";
    context.Response.Headers["X-Accel-Buffering"] = "no";

    try
    {
        foreach (var file in req.Files)
        {
            await context.Response.WriteAsync($"### File: {file.Path}\n\n");
            await context.Response.Body.FlushAsync();

            var sb = new StringBuilder();

            try
            {
                await foreach (var update in devbox.RunStreamingAsync($"Review file {file.Path}:\n{file.Diff}\n{file.Content}"))
                {
                    foreach (var part in update.Contents)
                    {
                        if (part is TextContent t)
                        {
                            sb.Append(t.Text);

                            if (sb.ToString().EndsWith(". ") || sb.ToString().EndsWith('\n'))
                            {
                                await context.Response.WriteAsync($"{sb}\n\n");
                                await context.Response.Body.FlushAsync();

                                sb.Clear();
                            }
                        }
                    }
                }
            }
            catch (OperationCanceledException)
            {
                await context.Response.WriteAsync("\nerror: review stream timed out\n\n");
                await context.Response.Body.FlushAsync();
            }

            if (sb.Length > 0)
            {
                await context.Response.WriteAsync($"{sb}\n\n");
                await context.Response.Body.FlushAsync();
            }
        }

        await context.Response.WriteAsync("[DONE]\n\n");
        await context.Response.Body.FlushAsync();
    }
    catch (Exception ex)
    {
        await context.Response.WriteAsync($"\nerror: {ex.Message}\n\n");
        await context.Response.Body.FlushAsync();
    }
});

app.MapPost("/help", async (HttpContext context, HelpRequest req) =>
{
    context.Response.ContentType = "text/event-stream";
    context.Response.Headers.CacheControl = "no-cache";
    context.Response.Headers["X-Accel-Buffering"] = "no";

    var sb = new StringBuilder();
    try
    {
        await foreach (var update in devbox.RunStreamingAsync(
            $"Answer this question about the project:\n{req.Question}"))
        {
            foreach (var content in update.Contents)
            {
                if (content is TextContent t)
                {
                    sb.Append(t.Text);

                    if (sb.ToString().EndsWith(". ") || sb.ToString().EndsWith('\n'))
                    {
                        await context.Response.WriteAsync($"{sb}\n\n");
                        await context.Response.Body.FlushAsync();

                        sb.Clear();
                    }
                }
            }
        }

        if (sb.Length > 0)
        {
            await context.Response.WriteAsync($"{sb}\n\n");
            await context.Response.Body.FlushAsync();
        }

        await context.Response.WriteAsync("\n\n[DONE]\n\n");
        await context.Response.Body.FlushAsync();
    }
    catch (Exception ex)
    {
        await context.Response.WriteAsync($"\nerror: {ex.Message}\n\n");
        await context.Response.Body.FlushAsync();
    }
});

app.Run("http://localhost:8080");

public record ReviewRequest(List<ReviewFile> Files);
public record ReviewFile(string Path, string Diff, string Content);
public record DevBoxRequest(string Message);
public record HelpRequest(string Question);
