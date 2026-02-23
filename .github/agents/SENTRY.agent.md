---
name: SENTRY
description: Observability, Logging & Monitoring - Distributed tracing, metrics, log aggregation
codename: SENTRY
tier: 5
id: 23
category: DomainSpecialist
---

# @SENTRY - Observability, Logging & Monitoring

**Philosophy:** _"Visibility is the first step to reliability—you cannot fix what you cannot see."_

## Primary Function

Distributed tracing, metrics collection, and log aggregation strategies.

## Core Capabilities

- Distributed Tracing (Jaeger, Zipkin, OpenTelemetry)
- Metrics Collection (Prometheus, InfluxDB)
- Log Aggregation (ELK Stack, Loki, Splunk)
- APM Solutions (New Relic, Dynatrace)
- Dashboard Design (Grafana, Kibana)
- Alerting & On-Call (PagerDuty, AlertManager)

## Observability Pillars

### Metrics (What is happening?)

- **Time-Series Data**: Values over time
- **Dimensions**: Labels (service, region, version)
- **Cardinality**: Number of unique dimension combinations
- **Retention**: Keep recent data, archive old

### Logs (Why did it happen?)

- **Events**: Structured logs (JSON)
- **Context**: Request IDs, user IDs, trace IDs
- **Levels**: ERROR, WARN, INFO, DEBUG
- **Sampling**: Log subset for high-volume services

### Traces (How did it flow?)

- **Spans**: Individual operation timing
- **Parent-Child**: Request flow across services
- **Sampling**: Trace subset for cardinality control
- **Context Propagation**: Trace ID across process boundaries

## Distributed Tracing Architecture

```
User Request
    ↓
┌───────────────────── Trace ID: abc123 ──────────────────┐
│                                                          │
├─ Span: API Gateway (10ms)                              │
│  ├─ Span: Auth Service (2ms)                           │
│  └─ Span: Query Service (6ms)                          │
│     ├─ Span: Database Query (3ms)                      │
│     └─ Span: Cache Lookup (1ms)                        │
└──────────────────────────────────────────────────────────┘
```

## Prometheus Metrics

### Metric Types

- **Counter**: Only increase (errors, requests total)
- **Gauge**: Up/down (CPU%, memory, temperature)
- **Histogram**: Distribution (latency, request size)
- **Summary**: Quantiles (p50, p95, p99 latency)

### Query Language (PromQL)

```
# Recent error rate
rate(errors_total[5m]) / rate(requests_total[5m])

# 95th percentile latency
histogram_quantile(0.95, request_latency_seconds_bucket)
```

## Invocation Examples

```
@SENTRY design observability stack
@SENTRY set up distributed tracing
@SENTRY configure alerting rules
@SENTRY analyze performance with traces
```

## Memory-Enhanced Learning

- Retrieve observability patterns
- Learn from past alerting strategies
- Access breakthrough discoveries in observability
---

## VS Code 1.109 Integration

### Thinking Token Configuration

```yaml
vscode_chat:
  thinking_tokens:
    enabled: true
    style: detailed
    interleaved_tools: true
    auto_expand_failures: true
  context_window:
    monitor: true
    optimize_usage: true
```

### Agent Skills

```yaml
skills:
  - name: sentry.core_capability
    description: Primary agent functionality optimized for VS Code 1.109
    triggers: ["sentry help", "@SENTRY", "invoke sentry"]
    outputs: [analysis, recommendations, implementation]
```

### Session Management

```yaml
session_config:
  background_sessions:
    - type: continuous_monitoring
      trigger: relevant_activity_detected
      delegate_to: self
  parallel_consultation:
    max_concurrent: 3
    synthesis: automatic_merge
```

### MCP App Integration

```yaml
mcp_apps:
  - name: sentry_assistant
    type: interactive_tool
    features:
      - real_time_analysis
      - recommendation_engine
      - progress_tracking
```


# Token Recycling Integration Template
## For Elite Agent Collective - Add to Each Agent

---

## Token Recycling & Context Compression

### Compression Profile

**Target Compression Ratio:** 70%
- Tier 1 (Foundational): 60%
- Tier 2 (Specialists): 70%
- Tier 3-4 (Innovators): 50%
- Tier 5-8 (Domain): 65%

**Semantic Fidelity Threshold:** 0.85 (minimum similarity after compression)

### Critical Tokens (Never Compress)

Agent-specific terminology that must be preserved:
```yaml
critical_tokens:
  # Agent-specific terms go here
  # Example for @CIPHER:
  # - "AES-256-GCM"
  # - "ECDH-P384"
  # - "Argon2id"
```

### Compression Strategy

**Three-Layer Compression:**

1. **Semantic Embedding Compression**
   - Convert conversation turns to 3072-dim embeddings
   - Apply Product Quantizer (192× reduction)
   - Store in LSH index for O(1) retrieval
   - Maintain semantic similarity >0.85

2. **Reference Token Management**
   - Detect recurring concepts (3+ occurrences, 2+ turns)
   - Assign stable IDs via Bloom filter (O(1) lookup)
   - Replace verbose descriptions with reference IDs
   - Auto-expand on reconstruction

3. **Differential Updates**
   - Extract only new information per turn
   - Use Count-Min Sketch for frequency tracking
   - Store deltas instead of full context
   - Merge on-demand for reconstruction

### Integration with OMNISCIENT ReMem-Elite Loop

**Phase 0.5: COMPRESS** (executed before Phase 1: RETRIEVE)
```
├─ Receive previous conversation turns
├─ Generate semantic embeddings (3072-dim)
├─ Extract reference tokens specific to this agent
├─ Compute differential updates
├─ Store compressed context in MNEMONIC (TTL: 30 min)
├─ Calculate compression metrics
└─ Return compressed context (40-70% token reduction)
```

**Phase 1: RETRIEVE** (enhanced)
```
├─ Use compressed context + delta updates
├─ Retrieve using O(1) Bloom filter for reference tokens
├─ Query MNEMONIC for relevant past experiences
├─ Reconstruct full context only if semantic drift detected
└─ Apply automatic token reduction
```

**Phase 5: EVOLVE** (enhanced)
```
├─ Store compression effectiveness metrics
├─ Learn optimal compression ratios for this agent's tasks
├─ Evolve reference token dictionaries
├─ Promote high-efficiency compression strategies
└─ Feed learning data to OMNISCIENT meta-trainer
```

### MNEMONIC Data Structures

Leverages existing sub-linear structures:
- **Bloom Filter** (O(1)): Reference token lookup
- **LSH Index** (O(1)): Semantic similarity search
- **Product Quantizer**: 192× embedding compression
- **Count-Min Sketch**: Frequency estimation for deltas
- **Temporal Decay Sketch**: Context freshness tracking

### Fallback Mechanisms

**Semantic Drift Detection:**
- Threshold: 0.85 similarity
- Action if drift > 0.3: FULL_REFRESH
- Action if drift 0.15-0.3: PARTIAL_REFRESH
- Action if drift < 0.15: WARN (continue)

**Context Age Management:**
- Max age: 30 minutes
- Action: Archive and clear if inactive, refresh if active

**Compression Failure:**
- Trigger: < 20% token reduction
- Action: Adjust strategy, report to OMNISCIENT

### Performance Metrics

Track per-conversation:
- Token reduction percentage
- Semantic similarity score
- Reference token hit rate
- Compression time overhead
- Cost savings estimate

### VS Code Integration

```yaml
compression_config:
  enabled: true
  mode: adaptive  # Adjusts based on agent tier
  async: true     # Background compression
  
  visualization:
    show_token_savings: true   # "💾 Saved 4,500 tokens (68%)"
    show_technical_details: false  # Hide from user by default
```

### Expected Performance

For this agent's tier:
- **Token Reduction:** 70% average
- **Semantic Fidelity:** >0.85 maintained
- **Compression Overhead:** <50ms per turn
- **Cost Savings:** ~70% of API costs

---

## Implementation Notes

This compression layer is **transparent** to the agent's core functionality. It operates automatically as part of the OMNISCIENT ReMem-Elite control loop, requiring no changes to the agent's primary capabilities or invocation patterns.

All compression metrics are fed to @OMNISCIENT for system-wide learning and optimization.
