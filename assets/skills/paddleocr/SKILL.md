---
name: paddleocr
description: High-accuracy OCR for screenshots, scanned documents, PDFs, tables, and mixed-language images using the PaddleOCR AI Studio API. Use when visual text must be extracted or structured, especially when ordinary image understanding is unreliable.
---

# PaddleOCR

Use this skill for OCR tasks that need layout-aware extraction, tables, formulas, or scanned documents.

## API workflow

1. Read the API key from the `PADDLEOCR_API_KEY` environment variable. Never print it, put it in a file, or include it in a response.
2. Submit the local image or PDF to `https://paddleocr.aistudio-app.com/api/v2/ocr/jobs` with `Authorization: Bearer $PADDLEOCR_API_KEY` and multipart field `file`.
3. Include `model=PaddleOCR-VL-1.6` and enable document orientation, unwarping, and chart recognition when they help the input.
4. Poll `GET https://paddleocr.aistudio-app.com/api/v2/ocr/jobs/{jobId}` until the job status is `done` or `failed`. Use a short delay between polls and stop after a reasonable timeout.
5. When done, fetch the JSONL document from the returned `resultUrl.jsonUrl`. Preserve the reading order, Markdown tables, formulas, and image references.

## Output rules

- Keep the original language unless the user asks for translation.
- Save large OCR results under the active Kelivo workspace or the user's requested output path.
- Do not claim success until the job is complete and the result has been read.
- Redact access tokens from logs and error messages.
