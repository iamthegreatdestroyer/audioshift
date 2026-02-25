#!/usr/bin/env python3
##
# AudioShift — Flame Graph Analysis & Comparison
# Phase 6 § Sprint 6.1.2
#
# Purpose:
#   Analyze flame graph performance data and compare against baseline.
#   Identifies CPU bottlenecks, regressions, and optimization opportunities.
#
# Usage:
#   ./scripts/profile/analyze_flamegraph.py [--baseline FILE] [--current FILE] [--threshold PERCENT]
#
# Metrics Calculated:
#   - Total CPU time spent in each function
#   - Call graph depth and branching
#   - Comparison against baseline (regression detection)
#   - Optimization recommendations
#
# Input: perf.data or out.perf (converted perf script output)
# Output: analysis.json, recommendations.md, visual comparison (if graphing available)
#
##

import sys
import json
import re
import argparse
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Set
from collections import defaultdict

# ─────────────────────────────────────────────────────────────────────────────
# Data structures
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class FunctionMetrics:
    name: str
    total_time_ms: float
    cpu_percentage: float
    call_count: int
    avg_time_ms: float
    max_time_ms: float
    parent_functions: List[str]
    child_functions: List[str]

class PerformanceAnalyzer:
    """Analyze flame graph and perf data for bottlenecks"""

    def __init__(self, perf_file: Path, threshold: float = 1.0):
        self.perf_file = perf_file
        self.threshold = threshold
        self.metrics: Dict[str, FunctionMetrics] = {}
        self.call_graph: Dict[str, Set[str]] = defaultdict(set)
        self.total_time_ms = 0.0

    def parse_perf_script(self) -> bool:
        """Parse perf script output format"""
        if not self.perf_file.exists():
            print(f"ERROR: File not found: {self.perf_file}")
            return False

        print(f"[INFO] Parsing perf output: {self.perf_file}")

        try:
            with open(self.perf_file, 'r') as f:
                lines = f.readlines()

            # Track function call statistics
            functions = defaultdict(lambda: {
                'count': 0,
                'times': [],
                'parents': set(),
                'children': set()
            })

            # Simple parsing: extract function names from stack traces
            # Format: function_name (overhead)
            current_stack = []

            for line in lines:
                line = line.strip()

                # Detect stack frame
                if line and not line.startswith('#') and not line.startswith(';'):
                    # Extract function name (usually until first space or paren)
                    match = re.match(r'^\s*([a-zA-Z_]\w+(?:::\w+)*)\s*\(', line)
                    if not match:
                        # Fallback: take first word
                        parts = line.split()
                        if parts:
                            func_name = parts[0].rstrip('();')
                            if func_name and func_name not in ['cpu-cycles', 'cpu-clock']:
                                current_stack.append(func_name)
                    else:
                        func_name = match.group(1)
                        current_stack.append(func_name)

                # Stack trace separator (empty line or new sample)
                elif line == '' and current_stack:
                    # Process completed stack
                    for i, func in enumerate(current_stack):
                        functions[func]['count'] += 1
                        if i > 0:
                            functions[func]['parents'].add(current_stack[i-1])
                        if i < len(current_stack) - 1:
                            functions[func]['children'].add(current_stack[i+1])
                    current_stack = []

            # Convert to metrics
            for func_name, data in functions.items():
                if data['count'] > 0:
                    # Estimate time: assume equal distribution across call stack
                    avg_time = 1.0  # 1ms per sample (would be more accurate with actual timestamps)
                    total_time = data['count'] * avg_time

                    self.metrics[func_name] = FunctionMetrics(
                        name=func_name,
                        total_time_ms=total_time,
                        cpu_percentage=(data['count'] / len(lines)) * 100 if lines else 0,
                        call_count=data['count'],
                        avg_time_ms=avg_time,
                        max_time_ms=total_time,
                        parent_functions=list(data['parents']),
                        child_functions=list(data['children'])
                    )

            self.total_time_ms = sum(m.total_time_ms for m in self.metrics.values())
            print(f"[✓] Parsed {len(self.metrics)} functions")
            return True

        except Exception as e:
            print(f"ERROR: Failed to parse perf file: {e}")
            return False

    def identify_bottlenecks(self) -> List[FunctionMetrics]:
        """Identify functions consuming most CPU time"""
        hotspots = [
            m for m in self.metrics.values()
            if m.cpu_percentage >= self.threshold
        ]
        hotspots.sort(key=lambda x: x.cpu_percentage, reverse=True)
        return hotspots

    def compare_baseline(self, baseline_file: Path) -> Dict:
        """Compare against baseline for regression detection"""
        if not baseline_file.exists():
            print(f"[⚠] Baseline not found: {baseline_file}")
            return {}

        print(f"[INFO] Loading baseline: {baseline_file}")

        try:
            with open(baseline_file, 'r') as f:
                baseline = json.load(f)

            regressions = []
            improvements = []

            for func_name, metrics in self.metrics.items():
                if func_name in baseline.get('metrics', {}):
                    baseline_pct = baseline['metrics'][func_name].get('cpu_percentage', 0)
                    delta = metrics.cpu_percentage - baseline_pct

                    if delta > 1.0:  # 1% regression threshold
                        regressions.append({
                            'function': func_name,
                            'baseline': baseline_pct,
                            'current': metrics.cpu_percentage,
                            'delta_percent': delta
                        })
                    elif delta < -0.5:  # 0.5% improvement
                        improvements.append({
                            'function': func_name,
                            'baseline': baseline_pct,
                            'current': metrics.cpu_percentage,
                            'delta_percent': delta
                        })

            return {
                'regressions': sorted(regressions, key=lambda x: x['delta_percent'], reverse=True),
                'improvements': sorted(improvements, key=lambda x: abs(x['delta_percent']), reverse=True)
            }

        except Exception as e:
            print(f"ERROR: Failed to compare baseline: {e}")
            return {}

    def generate_recommendations(self) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []
        hotspots = self.identify_bottlenecks()

        # Analyze top hotspot
        if hotspots:
            top = hotspots[0]

            if 'TDStretch' in top.name or 'SoundTouch' in top.name:
                recommendations.append(
                    f"🎯 HOTSPOT: {top.name} ({top.cpu_percentage:.1f}% CPU)"
                )
                recommendations.append(
                    "   → Verify SIMD enabled (SSE/NEON) in SoundTouch"
                )
                recommendations.append(
                    "   → Profile memory bandwidth (cache misses)"
                )
                recommendations.append(
                    "   → Consider NEON intrinsics for ARM64"
                )

            elif 'conversion' in top.name.lower() or 'float' in top.name.lower():
                recommendations.append(
                    f"🎯 HOTSPOT: {top.name} ({top.cpu_percentage:.1f}% CPU)"
                )
                recommendations.append(
                    "   → Optimize int16↔float conversion"
                )
                recommendations.append(
                    "   → Batch conversions to reduce call overhead"
                )
                recommendations.append(
                    "   → Consider NEON vfp4 intrinsics"
                )

            elif 'lock' in top.name.lower() or 'mutex' in top.name.lower():
                recommendations.append(
                    f"⚠️  LOCK CONTENTION: {top.name} ({top.cpu_percentage:.1f}% CPU)"
                )
                recommendations.append(
                    "   → Reduce critical section time"
                )
                recommendations.append(
                    "   → Consider lock-free data structures"
                )
                recommendations.append(
                    "   → Profile thread wake-up latency"
                )

            # Overall frame time check
            if self.total_time_ms > 0:
                frame_utilization = (self.total_time_ms / 20.0) * 100  # 20ms audio frame
                if frame_utilization > 75:
                    recommendations.append(
                        f"⚠️  HIGH FRAME UTILIZATION: {frame_utilization:.1f}%"
                    )
                    recommendations.append(
                        "   → CPU headroom limited, latency sensitive"
                    )
                    recommendations.append(
                        "   → Priorities: reduce TDStretch time, enable SIMD"
                    )
                elif frame_utilization < 50:
                    recommendations.append(
                        f"✓  Good frame utilization: {frame_utilization:.1f}%"
                    )
                    recommendations.append(
                        "   → Sufficient headroom for real-time processing"
                    )

        return recommendations

    def export_analysis(self, output_file: Path) -> bool:
        """Export analysis to JSON"""
        try:
            analysis = {
                'timestamp': Path(self.perf_file).stat().st_mtime,
                'perf_file': str(self.perf_file),
                'total_functions': len(self.metrics),
                'total_time_ms': self.total_time_ms,
                'metrics': {
                    name: asdict(metrics)
                    for name, metrics in self.metrics.items()
                },
                'hotspots': [
                    asdict(m) for m in self.identify_bottlenecks()[:10]
                ],
                'recommendations': self.generate_recommendations()
            }

            with open(output_file, 'w') as f:
                json.dump(analysis, f, indent=2, default=str)

            print(f"[✓] Analysis exported: {output_file}")
            return True

        except Exception as e:
            print(f"ERROR: Failed to export analysis: {e}")
            return False

    def print_summary(self):
        """Print analysis summary to stdout"""
        print("\n" + "="*60)
        print("PERFORMANCE ANALYSIS SUMMARY")
        print("="*60 + "\n")

        print(f"Total Functions: {len(self.metrics)}")
        print(f"Total CPU Time: {self.total_time_ms:.1f}ms")

        hotspots = self.identify_bottlenecks()
        if hotspots:
            print("\n🔥 TOP HOTSPOTS:")
            for i, h in enumerate(hotspots[:5], 1):
                print(f"  {i}. {h.name}")
                print(f"     CPU: {h.cpu_percentage:.1f}% | Calls: {h.call_count} | Avg: {h.avg_time_ms:.2f}ms")

        recommendations = self.generate_recommendations()
        if recommendations:
            print("\n💡 RECOMMENDATIONS:")
            for rec in recommendations:
                print(f"  {rec}")

        print("\n" + "="*60 + "\n")

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='AudioShift Flame Graph Analysis',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s out.perf
  %(prog)s --current out.perf --baseline baseline.json --threshold 2.0
  %(prog)s out.perf --compare research/baselines/flamegraph_baseline.json
        '''
    )

    parser.add_argument('perf_file', nargs='?', default='out.perf',
                        help='perf output file (default: out.perf)')
    parser.add_argument('--baseline', type=Path,
                        help='baseline analysis JSON for comparison')
    parser.add_argument('--threshold', type=float, default=1.0,
                        help='CPU % threshold for bottleneck detection (default: 1.0)')
    parser.add_argument('--output', type=Path, default=Path('analysis.json'),
                        help='output analysis file (default: analysis.json)')
    parser.add_argument('--compare', type=Path,
                        help='compare against baseline (alias for --baseline)')

    args = parser.parse_args()

    # Handle baseline alias
    if args.compare and not args.baseline:
        args.baseline = args.compare

    # Run analysis
    analyzer = PerformanceAnalyzer(Path(args.perf_file), threshold=args.threshold)

    if not analyzer.parse_perf_script():
        return 1

    analyzer.print_summary()

    # Compare against baseline if provided
    if args.baseline:
        comparison = analyzer.compare_baseline(args.baseline)
        if comparison:
            if comparison.get('regressions'):
                print("\n⚠️  REGRESSIONS DETECTED:")
                for reg in comparison['regressions'][:5]:
                    print(f"  {reg['function']}: {reg['delta_percent']:+.1f}% "
                          f"({reg['baseline']:.1f}% → {reg['current']:.1f}%)")
            if comparison.get('improvements'):
                print("\n✓ IMPROVEMENTS:")
                for imp in comparison['improvements'][:5]:
                    print(f"  {imp['function']}: {imp['delta_percent']:+.1f}% "
                          f"({imp['baseline']:.1f}% → {imp['current']:.1f}%)")

    # Export analysis
    analyzer.export_analysis(args.output)

    return 0

if __name__ == '__main__':
    sys.exit(main())
