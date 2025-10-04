# Generate-TestSlackExport.ps1
param(
  [string]$Root = ".\testdata"
)

$exp = Join-Path $Root "slack_export"
$filesDir = Join-Path $Root "file_payloads"
New-Item -ItemType Directory -Force -Path $exp,$filesDir | Out-Null

# Write metadata
@'
[
  { "id":"C10001","name":"engineering","created":1672617600,"is_archived":false,"topic":"Build & ship","purpose":"Engineering discussions" },
  { "id":"C10002","name":"hr","created":1675209600,"is_archived":false,"topic":"People ops","purpose":"HR policies and Q&A" },
  { "id":"C10003","name":"product-archived","created":1640908800,"is_archived":true,"topic":"","purpose":"Old product work" }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "channels.json")

@'
[
  { "id":"G20001","name":"finance","created":1680566400,"is_archived":false,"topic":"Numbers","purpose":"Private finance discussions" }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "groups.json")

@'
[
  { "id":"G30001","name":"mpim_U10001_U10002_U10005","created":1723939200,"members":["U10001","U10002","U10005"] }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "mpims.json")

@'
[
  { "id":"U10001","name":"karl","profile":{"real_name":"Karl Example","email":"karl@example.test"} },
  { "id":"U10002","name":"alexa","profile":{"real_name":"Alexa Rivera","email":"alexa@example.test"} },
  { "id":"U10003","name":"mina","profile":{"real_name":"Mina Patel","email":"mina@example.test"} },
  { "id":"U10004","name":"li","profile":{"real_name":"Li Chen","email":"li@example.test"} },
  { "id":"U10005","name":"samir","profile":{"real_name":"Samir Qadir","email":"samir@example.test"} }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "users.json")

# Helper to write message arrays
function Write-Day {
  param([string]$folder,[string]$date,[string]$json)
  $path = Join-Path $exp $folder
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  $file = Join-Path $path "$date.json"
  $json | Set-Content -Encoding UTF8 $file
}

# Engineering
Write-Day "engineering" "2023-06-01" @'
[
 { "type":"message","user":"U10001","text":"Eng: Kickoff 2023.","ts":"1685577600.000001" }
]
'@
Write-Day "engineering" "2024-11-15" @'
[
 { "type":"message","user":"U10002","text":"Eng: Mid-cycle note.","ts":"1731628800.000001" }
]
'@
Write-Day "engineering" "2025-07-10" @'
[
  { "type":"message","subtype":"thread_broadcast","user":"U10001","text":"Release 2.5 shipped! See files and notes.","ts":"1752105600.000001",
    "files":[ { "id":"F50001","name":"release-notes.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes.pdf" } ] },
  { "type":"message","user":"U10002","text":"Replying in thread. @karl please check diagram.","ts":"1752109200.000002","thread_ts":"1752105600.000001",
    "files":[ { "id":"F50002","name":"diagram.png","mimetype":"image/png","size":262144,"url_private":"sandbox://file_payloads/diagram.png" } ] },
  { "type":"message","user":"U10003","text":"Uploading large video for demo.","ts":"1752112800.000003",
    "files":[ { "id":"F50003","name":"large-video.mp4","mimetype":"video/mp4","size":62914560,"url_private":"sandbox://file_payloads/large-video.mp4" } ] }
]
'@

# HR
Write-Day "hr" "2025-01-05" @'
[
  { "type":"message","user":"U10004","text":"HR handbook v3 attached.","ts":"1736035200.000010",
    "files":[ { "id":"F50004","name":"handbook.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/handbook.pdf" } ] },
  { "type":"message","user":"U10002","text":"Please ignore this test channel message.","ts":"1736042400.000011" }
]
'@
Write-Day "hr" "2024-02-20" @'
[
  { "type":"message","user":"U10005","text":"HR retro action items.","ts":"1708387200.000012" }
]
'@

# Finance (private)
Write-Day "finance" "2023-04-12" @'
[
  { "type":"message","user":"U10005","text":"Q2 forecast (internal only).","ts":"1681267200.000020",
    "files":[ { "id":"F50005","name":"small-note.txt","mimetype":"text/plain","size":0,"url_private":"sandbox://file_payloads/small-note.txt" } ] },
  { "type":"message","user":"U10003","text":"Duplicate file name test.","ts":"1681270800.000021",
    "files":[ { "id":"F50006","name":"release-notes.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes.pdf" } ] }
]
'@

# Product (archived)
Write-Day "product-archived" "2022-12-31" @'
[
  { "type":"message","user":"U10001","text":"EOL notes for 2022 product.","ts":"1672444800.000030" }
]
'@

# DMs and MPIM
Write-Day "dm_U10001_U10002" "2023-05-01" @'
[
  { "type":"message","user":"U10001","text":"Private DM message with attachment.","ts":"1682899200.000040",
    "files":[ { "id":"F50007","name":"release-notes (1).pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes (1).pdf" } ] }
]
'@
Write-Day "dm_U10003_U10004" "2025-06-20" @'
[
  { "type":"message","user":"U10003","text":"DM close to present day.","ts":"1750377600.000041" }
]
'@
Write-Day "mpim_U10001_U10002_U10005" "2024-08-18" @'
[
  { "type":"message","user":"U10002","text":"MPIM kickoff.","ts":"1723939200.000050" }
]
'@

# Placeholder files
New-Item -ItemType File -Path (Join-Path $filesDir "small-note.txt") | Out-Null
fsutil file createnew (Join-Path $filesDir "handbook.pdf") 131072    | Out-Null
fsutil file createnew (Join-Path $filesDir "diagram.png")  262144    | Out-Null
fsutil file createnew (Join-Path $filesDir "release-notes.pdf") 131072 | Out-Null
fsutil file createnew (Join-Path $filesDir "release-notes (1).pdf") 131072 | Out-Null
fsutil file createnew (Join-Path $filesDir "large-video.mp4") 62914560 | Out-Null

Write-Host "Simulated Slack export generated at $exp"