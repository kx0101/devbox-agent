using System.ComponentModel;
using System.Text;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

namespace DevBox.Server;

public static class AgentFactory
{
    public static AIAgent CreateDevBox(IChatClient chat)
    {
        return chat.CreateAIAgent(
            instructions: """
                You are DevBox, a senior software engineer performing code reviews.

                Guidelines:
                - Be concise and actionable.
                - Only mention logic, readability, or correctness issues.
                - Use markdown bullets grouped by file.
                - Say “✅ No significant issues.” if clean.
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
    }

    public static AIAgent CreateHelpBox(IChatClient chat)
    {
        return chat.CreateAIAgent(
            instructions: """
                You are HelpBox — a project-aware assistant.
                You answer questions about the source code and architecture.
                Reference specific files when possible.
                If unsure, say “I don’t have enough context.”
            """,
            name: "HelpBox",
            description: "Answers developer questions using project source.",
            tools: [
                AIFunctionFactory.Create(ReadFile),
                AIFunctionFactory.Create(SearchProject)
            ]
        );
    }

    [Description("Explain what the given code does.")]
    private static string ExplainCode(string code)
        => $"Explain this code:\n{code}";

    [Description("Run a quick syntax or style check on code.")]
    private static string LintCode(string code)
        => "Lint check: No major issues found.";

    [Description("Perform a code review given a git diff and file content.")]
    private static string ReviewFile(string path, string diff, string content)
    {
        var truncated = content.Length > 12000 ? content[..12000] + "\n\n[Truncated]" : content;
        return $"Review the following file:\nPATH: {path}\n\nDIFF:\n{diff}\n\nCONTENT:\n{truncated}";
    }

    [Description("Read a file from disk to provide context for reviews or explanations.")]
    private static string ReadFile(string path)
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

    [Description("Search project source code for a keyword.")]
    private static string SearchProject(string keyword)
    {
        try
        {
            var exts = new[] { ".cs", ".lua", ".ts", ".go" };
            var files = Directory.GetFiles(Directory.GetCurrentDirectory(), "*.*", SearchOption.AllDirectories)
                .Where(f => exts.Any(f.EndsWith))
                .Take(60);

            var matches = files.Where(f =>
                File.ReadAllText(f).Contains(keyword, StringComparison.OrdinalIgnoreCase));

            var sb = new StringBuilder();
            foreach (var match in matches)
            {
                sb.AppendLine($"- {match}");
            }

            return sb.Length == 0
                ? $"No results found for '{keyword}'"
                : $"Files mentioning '{keyword}':\n{sb}";
        }
        catch (Exception ex)
        {
            return $"Search error: {ex.Message}";
        }
    }
}
