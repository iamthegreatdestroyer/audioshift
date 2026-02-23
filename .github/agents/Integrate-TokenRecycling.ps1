# Integrate Token Recycling into All Elite Agent Collective Agents
# This script adds the token recycling section to each agent file

$agentsPath = "S:\agents"
$templatePath = "$agentsPath\TOKEN_RECYCLING_TEMPLATE.md"
$backupPath = "$agentsPath\backups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Tier mappings for compression ratios
$tierMappings = @{
    "APEX" = @{ Tier = 1; Ratio = 60; Critical = @("O(1)", "O(log n)", "O(n)", "SOLID", "DRY") }
    "CIPHER" = @{ Tier = 1; Ratio = 60; Critical = @("AES-256-GCM", "ECDH-P384", "Argon2id", "SHA-256", "TLS 1.3") }
    "ARCHITECT" = @{ Tier = 1; Ratio = 60; Critical = @("microservices", "monolith", "CAP theorem", "ACID") }
    "AXIOM" = @{ Tier = 1; Ratio = 60; Critical = @("O(1)", "NP-complete", "P vs NP", "Big-O") }
    "VELOCITY" = @{ Tier = 1; Ratio = 60; Critical = @("latency", "throughput", "CPU", "memory") }
    "SYNAPSE" = @{ Tier = 2; Ratio = 70; Critical = @("API", "REST", "GraphQL", "gRPC") }
    "FLUX" = @{ Tier = 2; Ratio = 70; Critical = @("Kubernetes", "Docker", "CI/CD", "pipeline") }
    "CORE" = @{ Tier = 2; Ratio = 70; Critical = @("kernel", "syscall", "thread", "process") }
    "STREAM" = @{ Tier = 2; Ratio = 70; Critical = @("Kafka", "RabbitMQ", "pub/sub", "queue") }
    "TENSOR" = @{ Tier = 2; Ratio = 70; Critical = @("PyTorch", "TensorFlow", "neural network") }
    "PRISM" = @{ Tier = 2; Ratio = 70; Critical = @("CNN", "transformer", "attention", "embedding") }
    "NEURAL" = @{ Tier = 2; Ratio = 70; Critical = @("layer", "activation", "ReLU", "sigmoid") }
    "QUANTUM" = @{ Tier = 2; Ratio = 70; Critical = @("qubit", "superposition", "entanglement") }
    "LEDGER" = @{ Tier = 2; Ratio = 70; Critical = @("blockchain", "consensus", "smart contract") }
    "CRYPTO" = @{ Tier = 2; Ratio = 70; Critical = @("RSA", "ECC", "Diffie-Hellman", "public key") }
    "FORTRESS" = @{ Tier = 2; Ratio = 70; Critical = @("firewall", "IDS", "IPS", "WAF") }
    "PHANTOM" = @{ Tier = 2; Ratio = 70; Critical = @("penetration test", "exploit", "CVE") }
    "SENTRY" = @{ Tier = 2; Ratio = 70; Critical = @("observability", "metrics", "traces", "logs") }
    "ECLIPSE" = @{ Tier = 2; Ratio = 70; Critical = @("unit test", "integration test", "TDD") }
    "SCRIBE" = @{ Tier = 2; Ratio = 70; Critical = @("markdown", "documentation", "README") }
    "LINGUA" = @{ Tier = 2; Ratio = 70; Critical = @("NLP", "tokenization", "stemming") }
    "CANVAS" = @{ Tier = 2; Ratio = 70; Critical = @("SVG", "canvas", "WebGL", "Three.js") }
    "PHOTON" = @{ Tier = 2; Ratio = 70; Critical = @("React", "Vue", "Angular", "component") }
    "PULSE" = @{ Tier = 2; Ratio = 70; Critical = @("WebSocket", "SSE", "polling", "real-time") }
    "HELIX" = @{ Tier = 2; Ratio = 70; Critical = @("DNA", "RNA", "genome", "sequence") }
    "MORPH" = @{ Tier = 2; Ratio = 70; Critical = @("transformation", "migration", "refactor") }
    "NEXUS" = @{ Tier = 3; Ratio = 50; Critical = @("cross-domain", "pattern", "synthesis") }
    "GENESIS" = @{ Tier = 3; Ratio = 50; Critical = @("innovation", "novel", "paradigm") }
    "ORACLE" = @{ Tier = 3; Ratio = 50; Critical = @("prediction", "forecast", "trend") }
    "VANGUARD" = @{ Tier = 3; Ratio = 50; Critical = @("cutting-edge", "emerging", "frontier") }
    "OMNISCIENT" = @{ Tier = 4; Ratio = 50; Critical = @("meta-learning", "evolution", "orchestration") }
    "MENTOR" = @{ Tier = 4; Ratio = 50; Critical = @("teaching", "learning", "pedagogy") }
    "ARBITER" = @{ Tier = 4; Ratio = 50; Critical = @("decision", "trade-off", "evaluation") }
    "COMMUNICATOR" = @{ Tier = 4; Ratio = 50; Critical = @("interaction", "pattern", "communication") }
    "ATLAS" = @{ Tier = 5; Ratio = 65; Critical = @("AWS", "Azure", "GCP", "cloud") }
    "VERTEX" = @{ Tier = 6; Ratio = 65; Critical = @("edge", "CDN", "latency") }
    "AEGIS" = @{ Tier = 7; Ratio = 65; Critical = @("HIPAA", "PHI", "compliance", "medical") }
    "FORGE" = @{ Tier = 8; Ratio = 65; Critical = @("fintech", "payment", "PCI-DSS") }
    "LATTICE" = @{ Tier = 8; Ratio = 65; Critical = @("mesh", "service mesh", "Istio") }
    "BRIDGE" = @{ Tier = 8; Ratio = 65; Critical = @("integration", "connector", "adapter") }
    "ORBIT" = @{ Tier = 8; Ratio = 65; Critical = @("satellite", "space", "orbital") }
}

Write-Host "Creating backup directory: $backupPath" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

$template = Get-Content $templatePath -Raw

Write-Host ""
Write-Host "Integrating Token Recycling into all agents..." -ForegroundColor Green
Write-Host "================================================================================"

$agentFiles = Get-ChildItem -Path $agentsPath -Filter "*.agent.md"
$processedCount = 0
$skippedCount = 0

foreach ($agentFile in $agentFiles) {
    $agentName = $agentFile.BaseName -replace '\.agent$', ''
    
    Write-Host ""
    Write-Host "Processing: $agentName" -ForegroundColor Yellow
    
    Copy-Item $agentFile.FullName -Destination "$backupPath\$($agentFile.Name)" -Force
    Write-Host "  Backed up" -ForegroundColor Gray
    
    $agentContent = Get-Content $agentFile.FullName -Raw
    
    if ($agentContent -match "## Token Recycling") {
        Write-Host "  Already integrated - skipping" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    $mapping = $tierMappings[$agentName]
    if (-not $mapping) {
        Write-Host "  No tier mapping - using default Tier 2, 70%" -ForegroundColor Yellow
        $mapping = @{ Tier = 2; Ratio = 70; Critical = @() }
    }
    
    $customTemplate = $template -replace '\[TIER_SPECIFIC\]%', "$($mapping.Ratio)%"
    
    if ($mapping.Critical.Count -gt 0) {
        $criticalTokensYaml = ($mapping.Critical | ForEach-Object { "  - `"$_`"" }) -join "`n"
        $customTemplate = $customTemplate -replace '  # Agent-specific terms go here.*?```', "  # $agentName specific terms`n$criticalTokensYaml`n``````"
    }
    
    $newContent = $agentContent + "`n`n" + $customTemplate
    
    Set-Content -Path $agentFile.FullName -Value $newContent -NoNewline
    
    Write-Host "  Integrated Token Recycling" -ForegroundColor Green
    Write-Host "    Tier: $($mapping.Tier)" -ForegroundColor Gray
    Write-Host "    Compression Ratio: $($mapping.Ratio)%" -ForegroundColor Gray
    Write-Host "    Critical Tokens: $($mapping.Critical.Count)" -ForegroundColor Gray
    
    $processedCount++
}

Write-Host ""
Write-Host "================================================================================"
Write-Host ""
Write-Host "Integration Complete!" -ForegroundColor Green
Write-Host "  Processed: $processedCount agents" -ForegroundColor Cyan
Write-Host "  Skipped:   $skippedCount agents" -ForegroundColor Yellow
Write-Host "  Backed up: $backupPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review updated agents" -ForegroundColor White
Write-Host "  2. Test with OMNISCIENT Phase 0.5 integration" -ForegroundColor White
Write-Host "  3. Validate compression ratios" -ForegroundColor White
Write-Host "  4. Monitor token savings" -ForegroundColor White
