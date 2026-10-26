using Godot;
using PDFtoImage;
using SkiaSharp;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
 
/// <summary>
/// Renders every page of a PDF to an image file, off the main thread.
/// Attach to any Node (e.g. the root of a small scene), call StartConversion(),
/// and listen to ConversionFinished / ConversionFailed.
///
/// Requires NuGet: PDFtoImage (v4+). Desktop platforms only (Windows/Linux/macOS).
/// </summary>

/// Credit goes to claude for this part, I'm not familiar at all with c#

public partial class PdfRenderer : Node
{
	// ---------------------------------------------------------------- signals
 
	/// <summary>Emitted on the main thread when all pages are saved.</summary>
	[Signal]
	public delegate void ConversionFinishedEventHandler(string groupName, string outputDirectory, string[] files);
 
	/// <summary>Emitted on the main thread when the job failed (nothing is guaranteed to be written).</summary>
	[Signal]
	public delegate void ConversionFailedEventHandler(string groupName, string error);
 
	/// <summary>Emitted on the main thread after each page is written (page is 1-based).</summary>
	[Signal]
	public delegate void PageSavedEventHandler(string groupName, int page, int totalPages);
 
	// ---------------------------------------------------------------- internals
 
	private readonly CancellationTokenSource _cts = new();
	// PDFium is not thread-safe, so jobs are queued one after another.
	private static readonly SemaphoreSlim _gate = new(1, 1);
 
	public override void _ExitTree()
	{
		_cts.Cancel();
	}
 
	// ---------------------------------------------------------------- public API
 
	/// <summary>
	/// Starts a conversion in the background. Returns immediately.
	/// </summary>
	/// <param name="pdfPath">res://, user:// or absolute OS path to the PDF.</param>
	/// <param name="outputDir">res://, user:// or absolute OS path of the target folder (created if missing).
	/// Note: res:// is read-only in exported games; use user:// there.</param>
	/// <param name="groupName">Identifier for this set of images. Empty/null = auto-generated
	/// (pdf file name + short random id); the final name is always reported in the signals.</param>
	/// <param name="namingTemplate">File name without extension. Tokens: {name} = group name,
	/// {page} = page number (1-based, zero-padded to the page count's width),
	/// {page:000} = page number padded to an explicit width. Must contain {page}. Example: "{name}_p{page:000}".</param>
	/// <param name="dpi">Render resolution. 150 is a good default; 72 = PDF's native size.</param>
	/// <param name="format">"png" or "jpg".</param>
	/// <param name="password">Optional PDF password.</param>
	public void StartConversion(
		string pdfPath,
		string outputDir,
		string groupName,
		string namingTemplate = "{name}_{page}",
		int dpi = 150,
		string format = "png",
		string password = null)
	{
		// Resolve Godot paths on the main thread.
		string absPdf = ToAbsolute(pdfPath);
		string absOut = ToAbsolute(outputDir);
 
		if (string.IsNullOrWhiteSpace(groupName))
		{
			string baseName = Path.GetFileNameWithoutExtension(absPdf);
			groupName = $"{baseName}_{Guid.NewGuid().ToString("N")[..6]}";
		}
		groupName = SanitizeFileName(groupName);
 
		var token = _cts.Token;
		Task.Run(() => RunJob(absPdf, absOut, groupName, namingTemplate, dpi, format, password, token));
	}
 
	// ---------------------------------------------------------------- worker
 
	private async Task RunJob(
		string pdfPath, string outDir, string groupName, string template,
		int dpi, string format, string password, CancellationToken ct)
	{
		await _gate.WaitAsync(ct).ConfigureAwait(false);
		try
		{
			// --- validate
			if (!File.Exists(pdfPath))
				throw new FileNotFoundException($"PDF not found: {pdfPath}");
			if (string.IsNullOrWhiteSpace(template) || !Regex.IsMatch(template, @"\{page(:\d+)?\}"))
				throw new ArgumentException("Naming template must contain {page} (or {page:000}), otherwise files would overwrite each other.");
 
			bool isJpg = format.Equals("jpg", StringComparison.OrdinalIgnoreCase)
					  || format.Equals("jpeg", StringComparison.OrdinalIgnoreCase);
			if (!isJpg && !format.Equals("png", StringComparison.OrdinalIgnoreCase))
				throw new ArgumentException($"Unsupported format '{format}'. Use \"png\" or \"jpg\".");
 
			Directory.CreateDirectory(outDir);
 
			// --- load
			byte[] pdfBytes = await File.ReadAllBytesAsync(pdfPath, ct).ConfigureAwait(false);
 
			int totalPages;
			using (var countStream = new MemoryStream(pdfBytes))
				totalPages = Conversion.GetPageCount(countStream, leaveOpen: false, password: password);
 
			int autoWidth = totalPages.ToString().Length;
			string ext = isJpg ? ".jpg" : ".png";
			var options = new RenderOptions { Dpi = dpi };
			var written = new List<string>(totalPages);
 
			// --- render (lazy enumeration: one page in memory at a time)
			using var pdfStream = new MemoryStream(pdfBytes);
			int page = 0;
			foreach (SKBitmap bitmap in Conversion.ToImages(pdfStream, leaveOpen: false, password: password, options: options))
			{
				ct.ThrowIfCancellationRequested();
				page++;
 
				using (bitmap)
				using (var image = SKImage.FromBitmap(bitmap))
				using (var data = image.Encode(isJpg ? SKEncodedImageFormat.Jpeg : SKEncodedImageFormat.Png, isJpg ? 90 : 100))
				{
					string fileName = SanitizeFileName(ApplyTemplate(template, groupName, page, autoWidth)) + ext;
					string fullPath = Path.Combine(outDir, fileName);
					using (var fs = File.Create(fullPath))
						data.SaveTo(fs);
 
					written.Add(fullPath);
				}
 
				int p = page; // capture for lambda
				Callable.From(() => EmitSignal(SignalName.PageSaved, groupName, p, totalPages)).CallDeferred();
			}
 
			var files = written.ToArray();
			Callable.From(() => EmitSignal(SignalName.ConversionFinished, groupName, outDir, files)).CallDeferred();
		}
		catch (OperationCanceledException)
		{
			// Node left the tree; nobody is listening anymore.
		}
		catch (Exception e)
		{
			string msg = e.Message;
			Callable.From(() => EmitSignal(SignalName.ConversionFailed, groupName, msg)).CallDeferred();
		}
		finally
		{
			_gate.Release();
			QueueFree();
		}
	}
 
	// ---------------------------------------------------------------- helpers
 
	private static string ApplyTemplate(string template, string groupName, int page, int autoWidth)
	{
		string result = template.Replace("{name}", groupName);
		return Regex.Replace(result, @"\{page(?::(\d+))?\}", m =>
		{
			int width = m.Groups[1].Success ? m.Groups[1].Value.Length : autoWidth;
			return page.ToString().PadLeft(width, '0');
		});
	}
 
	private static string ToAbsolute(string path)
	{
		if (path.StartsWith("res://") || path.StartsWith("user://"))
			return ProjectSettings.GlobalizePath(path);
		return path;
	}
 
	private static string SanitizeFileName(string name)
	{
		foreach (char c in Path.GetInvalidFileNameChars())
			name = name.Replace(c, '_');
		return name;
	}
}
 
