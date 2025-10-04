Dataset‑linked test checklist
Date‑range window: Use 2025‑07‑01 to 2025‑07‑31 to capture engineering 2025‑07‑10 and exclude older content.

Default one‑year range: With no dates set, ensure 2024‑11‑15 (engineering) and 2025 content are included; 2023 and 2022 are excluded.

Skip messages by pattern: Add “test channel” to skip list; hr/2025‑01‑05 second message should skip.

Skip file types: Add “mp4” to SkipFileTypes; engineering large‑video.mp4 should skip download/upload.

Skip file size: Set SkipFileMaxSizeMB=50; large‑video.mp4 (60 MB) should skip, others proceed.

Duplicate file name handling: finance/release‑notes.pdf and dm/release‑notes (1).pdf exercise “Suffix” strategy.

Private channels: finance messages post to private Teams channel by default.

Threads: engineering thread from 2025‑07‑10 preserves thread fidelity.

DMs/MPIM: dm_* and mpim_* folders exercise DMStrategy=ActualChats.

Chunked uploads: With ChunkedUploads=true and SkipFileMaxSizeMB unset or high, large‑video.mp4 tests the upload session path.