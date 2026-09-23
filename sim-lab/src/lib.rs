use std::{
    cmp::Ordering,
    collections::{BTreeMap, BinaryHeap, HashMap, HashSet},
    fs,
    path::Path,
};

use alloy_primitives::{hex, keccak256, Address, B256, U256};
use alloy_signer::SignerSync;
use anyhow::{Context, Result};
use mesh_node::{
    api::{
        ClosureAckRecord, ClosureCandidateEvent, ClosureLateEventPolicy, ClosureProposalRecord,
        EpochClosedRecord, EventEpochAssignmentSource, NodeRuntime, PeerSetSnapshotRecord,
    },
    engine::MatchingEngine,
    preflight::PreflightEngine,
    store::NodeStore,
};
use proto_types::{
    sample_credit_signer_for_provider, sample_peer_auth, ClosureEpochClosed, ClosureProposal,
    IntentEnvelope, IntentPoolAttachmentV1, IntentSide, MarketTopic, PoolContributionV1,
    PoolExposureAttributionV1, PoolTermsV1, PoolV1, RuntimeProfileV1, SupportReleaseV1,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimRunConfigV1 {
    pub run_id: String,
    pub seed: u64,
    pub region: RegionConfigV1,
    pub topology: TopologyConfigV1,
    pub clock: ClockPolicyV1,
    pub network: LinkPolicyV1,
    #[serde(default)]
    pub partition_windows: Vec<PartitionWindowV1>,
    pub scenario: ScenarioConfigV1,
    pub output_report_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegionConfigV1 {
    pub region_id: String,
    pub market_topic: String,
    pub runtime_profile: RuntimeProfileV1,
    pub proposal_cutoff_ns: u64,
    pub ack_window_ns: u64,
    pub late_event_policy: ClosureLateEventPolicy,
    pub event_epoch_assignment_source: EventEpochAssignmentSource,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopologyConfigV1 {
    pub node_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClockPolicyV1 {
    pub base_skew_ns: i64,
    pub skew_step_ns: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LinkPolicyV1 {
    pub base_delay_ns: u64,
    pub jitter_ns: u64,
    pub drop_permille: u16,
    pub dup_permille: u16,
    pub corrupt_permille: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PartitionWindowV1 {
    pub from_ns: u64,
    pub to_ns: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScenarioConfigV1 {
    pub name: String,
    pub intent_pairs: usize,
    pub intent_interval_ns: u64,
    pub closure_epoch_id: u64,
    #[serde(default)]
    pub repair_depth_max: u64,
    #[serde(default)]
    pub emit_supersession: bool,
    #[serde(default)]
    pub settlement_retry_events: usize,
    #[serde(default)]
    pub settlement_retry_interval_ns: u64,
    #[serde(default = "default_closure_apply_skew_max_ns")]
    pub closure_apply_skew_max_ns: u64,
    pub checkpoint_times_ns: Vec<u64>,
    pub pool: PoolScenarioV1,
}

fn default_closure_apply_skew_max_ns() -> u64 {
    5_000_000
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolScenarioV1 {
    pub pool_id: String,
    pub market_id: String,
    pub contributor_count: usize,
    pub contribution_notional: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProofTupleV1 {
    pub node_id: String,
    pub accepted_epoch_ids: Vec<u64>,
    pub accepted_parent_hashes: Vec<String>,
    pub accepted_supersession_set: Vec<String>,
    pub final_closure_hash: Option<String>,
    pub final_market_state_digest: String,
    pub state_root_digest: String,
    pub cumulative_ledger_hash: String,
    pub pool_state_digest: String,
    pub settlement_projection_digest: Option<String>,
    pub reject_code_multiset: BTreeMap<String, u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimInvariantViolationV1 {
    pub node_id: String,
    pub invariant: String,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimRunReportV1 {
    pub run_id: String,
    pub seed: u64,
    pub scenario: String,
    pub accepted_epoch_ids: Vec<u64>,
    pub final_closure_hash: Option<String>,
    pub final_market_state_digest_set: Vec<String>,
    pub settlement_projection_digest_set: Vec<String>,
    pub first_divergent_epoch_id: Option<u64>,
    pub first_pre_epoch_root_split_epoch: Option<u64>,
    pub first_post_epoch_root_split_epoch: Option<u64>,
    pub first_root_split_class: Option<String>,
    pub first_canonical_tuple_split_epoch: Option<u64>,
    pub canonical_tuple_divergence_count: usize,
    pub closure_apply_completion_max_skew_ns: u64,
    pub closure_apply_dispatch_max_skew_ns: u64,
    pub closure_apply_skew_max_allowed_ns: u64,
    pub first_divergent_lane_class: Option<String>,
    pub closure_epoch_traces: Vec<ClosureEpochTraceV1>,
    pub first_divergent_epoch_analysis: Option<FirstDivergentEpochAnalysisV1>,
    pub proof_tuples: Vec<ProofTupleV1>,
    pub metrics: SimMetricsV1,
    pub divergence: Vec<String>,
    pub invariant_violations: Vec<SimInvariantViolationV1>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ClosureEpochTraceV1 {
    pub node_id: String,
    pub epoch_id: u64,
    pub proposer_id: Option<String>,
    pub proposal_digest: Option<String>,
    pub proposal_ordered_event_ids: Vec<String>,
    pub proposal_enqueue_time_ns: Option<u64>,
    pub proposal_publish_time_ns: Option<u64>,
    pub proposal_receive_time_ns: Option<u64>,
    pub proposal_publish_closure_queue_depth: usize,
    pub proposal_publish_settlement_queue_depth: usize,
    pub ack_enqueue_time_ns: Option<u64>,
    pub ack_publish_time_ns: Option<u64>,
    pub ack_receive_time_ns: Option<u64>,
    pub ack_publish_closure_queue_depth: usize,
    pub ack_publish_settlement_queue_depth: usize,
    pub ack_arrival_by_acker_ns: BTreeMap<String, u64>,
    pub quorum_threshold: u64,
    pub quorum_reached_time_ns: Option<u64>,
    pub epoch_closed_enqueue_time_ns: Option<u64>,
    pub epoch_closed_publish_time_ns: Option<u64>,
    pub epoch_closed_receive_time_ns: Option<u64>,
    pub epoch_closed_publish_closure_queue_depth: usize,
    pub epoch_closed_publish_settlement_queue_depth: usize,
    pub epoch_closed_hash: Option<String>,
    pub epoch_closed_ackers: Vec<String>,
    pub frozen_quorum_members: Vec<String>,
    pub pre_epoch_state_root: Option<String>,
    pub post_epoch_state_root: Option<String>,
    pub post_epoch_cumulative_ledger_hash: Option<String>,
    pub closure_apply_enqueue_time_ns: Option<u64>,
    pub closure_apply_dispatch_time_ns: Option<u64>,
    pub closure_apply_completion_time_ns: Option<u64>,
    pub market_mutation_count: u64,
    pub pool_mutation_count: u64,
    pub settlement_projection_mutation_count: u64,
    pub ledger_append_time_ns: Option<u64>,
    pub checkpoint_eligible: Option<bool>,
    pub checkpoint_emitted: Option<bool>,
    pub authority_snapshot_ids_seen: Vec<String>,
    pub mark_snapshot_ids_seen: Vec<String>,
    pub candidate_event_ids_seen: Vec<String>,
    pub settlement_retry_ids_seen: Vec<String>,
    pub authority_bucket_hash: Option<String>,
    pub mark_bucket_hash: Option<String>,
    pub candidate_bucket_hash: Option<String>,
    pub settlement_retry_bucket_hash: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct FirstDivergentEpochAnalysisV1 {
    pub epoch_id: u64,
    pub proposer_ids: Vec<String>,
    pub proposal_digests: Vec<String>,
    pub epoch_closed_hashes: Vec<String>,
    pub ack_set_hashes: Vec<String>,
    pub frozen_quorum_member_sets: Vec<Vec<String>>,
    pub ack_set_mismatch: bool,
    pub timing_only_split: bool,
}

#[derive(Debug, Clone, Default)]
struct EpochApplyOutcome {
    epoch_id: u64,
    pre_epoch_state_root: Option<String>,
    post_epoch_state_root: Option<String>,
    post_epoch_cumulative_ledger_hash: Option<String>,
    closure_apply_enqueue_time_ns: u64,
    closure_apply_dispatch_time_ns: u64,
    closure_apply_completion_time_ns: u64,
    market_mutation_count: u64,
    pool_mutation_count: u64,
    settlement_projection_mutation_count: u64,
    ledger_append_time_ns: Option<u64>,
    checkpoint_eligible: bool,
    checkpoint_emitted: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LatencySummaryV1 {
    pub count: usize,
    pub min_ns: Option<u64>,
    pub p50_ns: Option<u64>,
    pub p95_ns: Option<u64>,
    pub max_ns: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SimMetricsV1 {
    pub events_total: u64,
    pub messages_delivered: u64,
    pub messages_dropped: u64,
    pub dropped_messages: u64,
    pub duplicated_messages: u64,
    pub corrupted_messages: u64,
    pub partition_dropped_messages: u64,
    pub max_queue_depth: usize,
    pub avg_delivery_delay_ns: u64,
    pub max_delivery_delay_ns: u64,
    pub transport_latency_by_class: BTreeMap<String, LatencySummaryV1>,
    pub lane_metrics: BTreeMap<String, SimClassMetricsV1>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SimClassMetricsV1 {
    pub count: u64,
    pub delivered: u64,
    pub dropped: u64,
    pub duplicated: u64,
    pub avg_delay_ns: u64,
    pub p50_delay_ns: u64,
    pub p95_delay_ns: u64,
    pub max_delay_ns: u64,
    pub queue_max_seen: usize,
}

struct SimNode {
    node_id: String,
    runtime: NodeRuntime,
}

#[derive(Debug, Clone)]
enum SimMessage {
    Intent(IntentEnvelope),
    PeerSetSnapshot(PeerSetSnapshotRecord),
    Pool(PoolV1),
    PoolTerms(PoolTermsV1),
    PoolContribution(PoolContributionV1),
    IntentPoolAttachment(IntentPoolAttachmentV1),
    PoolExposureAttribution(PoolExposureAttributionV1),
    SupportRelease(SupportReleaseV1),
    AuthoritySnapshot(proto_types::AuthoritySnapshotEvent),
    MarkSnapshot(proto_types::MarkSnapshotEvent),
    ClosureCandidate(ClosureCandidateEvent),
    ClosureProposal(ClosureProposal),
    ClosureAck(proto_types::ClosureAck),
    ClosureEpochClosed(ClosureEpochClosed),
    EpochSuperseded(mesh_node::api::EpochSupersededRecord),
    SettlementControl { _retry_id: String },
}

#[derive(Debug, Clone)]
enum SimEvent {
    Broadcast {
        src: usize,
        msg: SimMessage,
        enqueued_at_ns: u64,
    },
    Deliver {
        dst: usize,
        msg: SimMessage,
        published_at_ns: u64,
    },
    SubmitIntent {
        src: usize,
        intent: IntentEnvelope,
    },
    ExtractCheckpoint,
}

#[derive(Debug, Clone)]
struct ScheduledEvent {
    at_ns: u64,
    priority: u8,
    seq: u64,
    event: SimEvent,
}

impl PartialEq for ScheduledEvent {
    fn eq(&self, other: &Self) -> bool {
        self.at_ns == other.at_ns && self.seq == other.seq
    }
}
impl Eq for ScheduledEvent {}

impl PartialOrd for ScheduledEvent {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for ScheduledEvent {
    fn cmp(&self, other: &Self) -> Ordering {
        // reversed for min-heap behavior via BinaryHeap
        other
            .at_ns
            .cmp(&self.at_ns)
            .then_with(|| other.priority.cmp(&self.priority))
            .then_with(|| other.seq.cmp(&self.seq))
    }
}

#[derive(Debug, Clone)]
struct LcgRng {
    state: u64,
}

impl LcgRng {
    fn new(seed: u64) -> Self {
        Self { state: seed.max(1) }
    }

    fn next_u64(&mut self) -> u64 {
        self.state = self
            .state
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.state
    }

    fn roll_permille(&mut self, permille: u16) -> bool {
        if permille == 0 {
            return false;
        }
        (self.next_u64() % 1000) < u64::from(permille)
    }

    fn jitter(&mut self, max: u64) -> u64 {
        if max == 0 {
            0
        } else {
            self.next_u64() % max
        }
    }
}

pub fn load_config(path: &Path) -> Result<SimRunConfigV1> {
    let raw = fs::read(path).with_context(|| format!("read {}", path.display()))?;
    serde_json::from_slice(&raw).context("parse SimRunConfigV1")
}

pub fn run(config: SimRunConfigV1, workspace_root: &Path) -> Result<SimRunReportV1> {
    let mut rng = LcgRng::new(config.seed);
    let mut nodes = build_nodes(&config, workspace_root)?;
    seed_peer_auths(&config, &mut nodes)?;

    let mut queue = BinaryHeap::<ScheduledEvent>::new();
    let mut metrics = SimMetricsV1::default();
    let mut transport_samples = BTreeMap::<String, Vec<u64>>::new();
    let mut lane_samples = BTreeMap::<String, Vec<u64>>::new();
    let mut lane_metrics = BTreeMap::<String, SimClassMetricsV1>::new();
    let mut in_flight_by_lane = BTreeMap::<String, usize>::new();
    let mut closure_epoch_trace = BTreeMap::<(String, u64), ClosureEpochTraceV1>::new();
    let mut seq = 0u64;
    let mut schedule = |at_ns: u64, event: SimEvent, queue: &mut BinaryHeap<ScheduledEvent>| {
        seq = seq.saturating_add(1);
        queue.push(ScheduledEvent {
            at_ns,
            priority: scheduled_event_priority(&event),
            seq,
            event,
        });
    };

    enqueue_bootstrap_messages(&config, &mut schedule, &mut queue);
    enqueue_intents(&config, &mut schedule, &mut queue);
    enqueue_closure_path(&config, &mut schedule, &mut queue);
    for t in &config.scenario.checkpoint_times_ns {
        schedule(*t, SimEvent::ExtractCheckpoint, &mut queue);
    }

    while let Some(ScheduledEvent { at_ns, event, .. }) = queue.pop() {
        metrics.events_total = metrics.events_total.saturating_add(1);
        match event {
            SimEvent::Broadcast {
                src,
                msg,
                enqueued_at_ns,
            } => {
                let lane = message_lane_class(&msg).to_owned();
                maybe_record_closure_publish_trace(
                    &nodes,
                    src,
                    at_ns,
                    enqueued_at_ns,
                    &msg,
                    &in_flight_by_lane,
                    &mut closure_epoch_trace,
                );
                for dst in 0..nodes.len() {
                    lane_metrics.entry(lane.clone()).or_default().count = lane_metrics
                        .get(&lane)
                        .map(|m| m.count)
                        .unwrap_or(0)
                        .saturating_add(1);
                    if is_partitioned(at_ns, src, dst, &config.partition_windows) {
                        metrics.partition_dropped_messages =
                            metrics.partition_dropped_messages.saturating_add(1);
                        lane_metrics.entry(lane.clone()).or_default().dropped = lane_metrics
                            .get(&lane)
                            .map(|m| m.dropped)
                            .unwrap_or(0)
                            .saturating_add(1);
                        continue;
                    }
                    if rng.roll_permille(config.network.drop_permille) {
                        metrics.dropped_messages = metrics.dropped_messages.saturating_add(1);
                        lane_metrics.entry(lane.clone()).or_default().dropped = lane_metrics
                            .get(&lane)
                            .map(|m| m.dropped)
                            .unwrap_or(0)
                            .saturating_add(1);
                        continue;
                    }
                    let delay = config
                        .network
                        .base_delay_ns
                        .saturating_add(rng.jitter(config.network.jitter_ns));
                    let (deliver_msg, corrupted) =
                        maybe_corrupt(&mut rng, &config.network, msg.clone());
                    if corrupted {
                        metrics.corrupted_messages = metrics.corrupted_messages.saturating_add(1);
                    }
                    schedule(
                        at_ns.saturating_add(delay),
                        SimEvent::Deliver {
                            dst,
                            msg: deliver_msg,
                            published_at_ns: at_ns,
                        },
                        &mut queue,
                    );
                    let current = in_flight_by_lane.entry(lane.clone()).or_default();
                    *current = current.saturating_add(1);
                    let lane_entry = lane_metrics.entry(lane.clone()).or_default();
                    lane_entry.queue_max_seen = lane_entry.queue_max_seen.max(*current);
                    if rng.roll_permille(config.network.dup_permille) {
                        metrics.duplicated_messages = metrics.duplicated_messages.saturating_add(1);
                        lane_metrics.entry(lane.clone()).or_default().duplicated = lane_metrics
                            .get(&lane)
                            .map(|m| m.duplicated)
                            .unwrap_or(0)
                            .saturating_add(1);
                        schedule(
                            at_ns.saturating_add(delay.saturating_add(1)),
                            SimEvent::Deliver {
                                dst,
                                msg: msg.clone(),
                                published_at_ns: at_ns,
                            },
                            &mut queue,
                        );
                        let current = in_flight_by_lane.entry(lane.clone()).or_default();
                        *current = current.saturating_add(1);
                        let lane_entry = lane_metrics.entry(lane.clone()).or_default();
                        lane_entry.queue_max_seen = lane_entry.queue_max_seen.max(*current);
                    }
                    metrics.max_queue_depth = metrics.max_queue_depth.max(queue.len());
                }
            }
            SimEvent::Deliver {
                dst,
                msg,
                published_at_ns,
            } => {
                let class = message_class(&msg).to_owned();
                let lane = message_lane_class(&msg).to_owned();
                let transport = at_ns.saturating_sub(published_at_ns);
                metrics.messages_delivered = metrics.messages_delivered.saturating_add(1);
                metrics.max_delivery_delay_ns = metrics.max_delivery_delay_ns.max(transport);
                transport_samples.entry(class).or_default().push(transport);
                lane_samples
                    .entry(lane.clone())
                    .or_default()
                    .push(transport);
                lane_metrics.entry(lane.clone()).or_default().delivered = lane_metrics
                    .get(&lane)
                    .map(|m| m.delivered)
                    .unwrap_or(0)
                    .saturating_add(1);
                if let Some(current) = in_flight_by_lane.get_mut(&lane) {
                    *current = current.saturating_sub(1);
                }
                maybe_record_closure_receive_trace(
                    &nodes,
                    dst,
                    at_ns,
                    &msg,
                    &mut closure_epoch_trace,
                );
                maybe_record_epoch_input_observation(
                    &config,
                    &nodes,
                    dst,
                    at_ns,
                    &msg,
                    &mut closure_epoch_trace,
                );
                let apply = apply_message(&config, &mut nodes[dst], msg, at_ns)?;
                if let Some(outcome) = apply {
                    maybe_record_closure_apply_trace(
                        &nodes,
                        dst,
                        outcome,
                        &mut closure_epoch_trace,
                    );
                }
            }
            SimEvent::SubmitIntent { src, intent } => {
                schedule(
                    at_ns,
                    SimEvent::Broadcast {
                        src,
                        msg: SimMessage::Intent(intent),
                        enqueued_at_ns: at_ns,
                    },
                    &mut queue,
                );
            }
            SimEvent::ExtractCheckpoint => {}
        }
        metrics.max_queue_depth = metrics.max_queue_depth.max(queue.len());
    }

    let mut total_transport_samples = 0u128;
    let mut total_transport_sum = 0u128;
    metrics.transport_latency_by_class = transport_samples
        .into_iter()
        .map(|(class, samples)| {
            total_transport_samples = total_transport_samples.saturating_add(samples.len() as u128);
            total_transport_sum = total_transport_sum
                .saturating_add(samples.iter().copied().map(u128::from).sum::<u128>());
            (class, summarize_latency(samples))
        })
        .collect();
    metrics.avg_delivery_delay_ns = if total_transport_samples == 0 {
        0
    } else {
        (total_transport_sum / total_transport_samples) as u64
    };
    metrics.messages_dropped = metrics
        .dropped_messages
        .saturating_add(metrics.partition_dropped_messages);
    let mut finalized_lane = BTreeMap::<String, SimClassMetricsV1>::new();
    for (lane, mut lane_metric) in lane_metrics {
        let samples = lane_samples.remove(&lane).unwrap_or_default();
        let sum: u128 = samples.iter().copied().map(u128::from).sum();
        let summary = summarize_latency(samples);
        lane_metric.avg_delay_ns = if summary.count == 0 {
            0
        } else {
            (sum / summary.count as u128) as u64
        };
        lane_metric.p50_delay_ns = summary.p50_ns.unwrap_or(0);
        lane_metric.p95_delay_ns = summary.p95_ns.unwrap_or(0);
        lane_metric.max_delay_ns = summary.max_ns.unwrap_or(0);
        lane_metric.count = lane_metric
            .delivered
            .saturating_add(lane_metric.dropped)
            .saturating_add(lane_metric.duplicated);
        finalized_lane.insert(lane, lane_metric);
    }
    for lane in [
        "closure_control",
        "market_critical",
        "pool_support",
        "settlement_control",
        "sync_control",
    ] {
        finalized_lane.entry(lane.to_owned()).or_default();
    }
    metrics.lane_metrics = finalized_lane;

    let mut proof_tuples = Vec::new();
    let mut invariant_violations = Vec::new();
    for node in &mut nodes {
        let proof = extract_proof_tuple(node, &config.region.region_id)?;
        check_pool_invariants(node, &proof, &mut invariant_violations);
        proof_tuples.push(proof);
    }
    let mut closure_epoch_traces = closure_epoch_trace.into_values().collect::<Vec<_>>();
    closure_epoch_traces.sort_by(|a, b| {
        a.epoch_id
            .cmp(&b.epoch_id)
            .then_with(|| a.node_id.cmp(&b.node_id))
    });
    let report = compile_report(
        &config,
        proof_tuples,
        invariant_violations,
        metrics,
        closure_epoch_traces,
    );
    write_report(&report, workspace_root, &config.output_report_path)?;
    Ok(report)
}

fn build_nodes(config: &SimRunConfigV1, workspace_root: &Path) -> Result<Vec<SimNode>> {
    let mut nodes = Vec::new();
    let root = workspace_root
        .join("var")
        .join("sim")
        .join(config.run_id.as_str());
    fs::create_dir_all(&root).with_context(|| format!("create {}", root.display()))?;
    for idx in 0..config.topology.node_count {
        let node_id = format!("sim-node-{}", idx + 1);
        let store = NodeStore::at(root.join(&node_id))
            .with_context(|| format!("create node store for {node_id}"))?;
        let mut runtime =
            NodeRuntime::new(MatchingEngine::default(), PreflightEngine::default(), store);
        runtime.apply_runtime_profile(config.region.runtime_profile.clone());
        runtime.set_closure_policy(
            config.region.proposal_cutoff_ns,
            config.region.ack_window_ns,
            config.region.late_event_policy,
            config.region.event_epoch_assignment_source,
        );
        runtime.set_hint_reporter_id(node_id.clone());
        nodes.push(SimNode { node_id, runtime });
    }
    Ok(nodes)
}

fn seed_peer_auths(config: &SimRunConfigV1, nodes: &mut [SimNode]) -> Result<()> {
    let mut parts = config.region.market_topic.split('/');
    let region = parts.nth(1).unwrap_or("frankfurt").to_owned();
    let venue_market = parts.next().unwrap_or("perps-xxw-usd");
    let mut vm_parts = venue_market.split('-');
    let venue = vm_parts.next().unwrap_or("perps").to_owned();
    let market = vm_parts.collect::<Vec<_>>().join("-");
    let topic = MarketTopic {
        region,
        venue,
        market,
        version: 1,
    };
    let auths = nodes
        .iter()
        .map(|node| sample_peer_auth(&node.node_id, &topic))
        .collect::<Vec<_>>();
    for node in nodes.iter_mut() {
        for auth in &auths {
            node.runtime.observe_peer_auth(auth)?;
        }
    }
    Ok(())
}

fn enqueue_bootstrap_messages(
    config: &SimRunConfigV1,
    schedule: &mut impl FnMut(u64, SimEvent, &mut BinaryHeap<ScheduledEvent>),
    queue: &mut BinaryHeap<ScheduledEvent>,
) {
    let at = 1_000_000u64;
    let terms_hash = format!("0x{}", hex::encode(keccak256("pool-terms-v1".as_bytes())));
    let pool = PoolV1 {
        pool_id: config.scenario.pool.pool_id.clone(),
        region_id: config.region.region_id.clone(),
        market_id: config.scenario.pool.market_id.clone(),
        terms_hash: terms_hash.clone(),
        total_notional: config.scenario.pool.contribution_notional.clone(),
        reserved_notional: "0".to_owned(),
        active: true,
        updated_at_ns: at,
    };
    let terms = PoolTermsV1 {
        pool_id: config.scenario.pool.pool_id.clone(),
        region_id: config.region.region_id.clone(),
        market_id: config.scenario.pool.market_id.clone(),
        leverage_max_bps: 50_000,
        margin_floor: "1000000".to_owned(),
        cp_fee_bps: 75,
        effective_from_ns: at,
        expiry_ns: at.saturating_add(30_000_000_000),
        terms_hash,
    };
    schedule(
        at,
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::Pool(pool),
            enqueued_at_ns: at,
        },
        queue,
    );
    schedule(
        at.saturating_add(1),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::PoolTerms(terms),
            enqueued_at_ns: at.saturating_add(1),
        },
        queue,
    );
    for i in 0..config.scenario.pool.contributor_count {
        let wallet = if i % 2 == 0 {
            proto_types::sample_credit_signer().address()
        } else {
            proto_types::sample_credit_signer_two().address()
        };
        let contribution = PoolContributionV1 {
            pool_id: config.scenario.pool.pool_id.clone(),
            contributor_wallet: wallet,
            notional: config.scenario.pool.contribution_notional.clone(),
            contribution_nonce: i as u64 + 1,
            observed_at_ns: at.saturating_add(i as u64 + 2),
            contribution_hash: format!(
                "0x{}",
                hex::encode(keccak256(format!("contribution-{}", i + 1).as_bytes()))
            ),
        };
        schedule(
            at.saturating_add(i as u64 + 2),
            SimEvent::Broadcast {
                src: 0,
                msg: SimMessage::PoolContribution(contribution),
                enqueued_at_ns: at.saturating_add(i as u64 + 2),
            },
            queue,
        );
    }

    let authority = proto_types::AuthoritySnapshotEvent {
        snapshot_id: "authority-sim-1".to_owned(),
        source_block: 1,
        timestamp_ns: at.saturating_add(20),
        accounts: vec![proto_types::AuthorityAccountSnapshot {
            trader: proto_types::sample_trader_signer().address(),
            token: Address::repeat_byte(0x78),
            free_collateral: U256::from(5_000_000u64),
            permit2_capacity: U256::from(5_000_000u64),
            delegation_active: true,
            nonce_frontier: U256::from(0u64),
        }],
    };
    schedule(
        at.saturating_add(20),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::AuthoritySnapshot(authority),
            enqueued_at_ns: at.saturating_add(20),
        },
        queue,
    );

    let mark = proto_types::MarkSnapshotEvent {
        snapshot_id: "mark-sim-1".to_owned(),
        timestamp_ns: at.saturating_add(21),
        marks: vec![proto_types::MarkSnapshotPoint {
            market_id: B256::repeat_byte(0x4b),
            price_feed_id: B256::repeat_byte(0x39),
            mark_price_x18: U256::from(100_000u64) * proto_types::price_x18_scale(),
            observed_at: proto_types::unix_now_secs(),
            source: "sim".to_owned(),
        }],
    };
    schedule(
        at.saturating_add(21),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::MarkSnapshot(mark),
            enqueued_at_ns: at.saturating_add(21),
        },
        queue,
    );

    let attachment = IntentPoolAttachmentV1 {
        intent_id: "intent-sim-1".to_owned(),
        pool_id: config.scenario.pool.pool_id.clone(),
        requested_notional: "1000000".to_owned(),
        max_slippage_bps: 50,
        attachment_nonce: 1,
        attachment_hash: format!("0x{}", hex::encode(keccak256("attachment-1".as_bytes()))),
    };
    schedule(
        at.saturating_add(22),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::IntentPoolAttachment(attachment),
            enqueued_at_ns: at.saturating_add(22),
        },
        queue,
    );

    let attribution = PoolExposureAttributionV1 {
        pool_id: config.scenario.pool.pool_id.clone(),
        intent_id: "intent-sim-1".to_owned(),
        match_id: "match-sim-1".to_owned(),
        attributed_notional: "500000".to_owned(),
        residual_notional: "500000".to_owned(),
        event_sequence: 1,
        attribution_hash: format!("0x{}", hex::encode(keccak256("attribution-1".as_bytes()))),
    };
    schedule(
        at.saturating_add(23),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::PoolExposureAttribution(attribution),
            enqueued_at_ns: at.saturating_add(23),
        },
        queue,
    );

    let release = SupportReleaseV1 {
        pool_id: config.scenario.pool.pool_id.clone(),
        intent_id: "intent-sim-1".to_owned(),
        released_notional: "250000".to_owned(),
        reason: "partial_close".to_owned(),
        event_sequence: 2,
        release_hash: format!("0x{}", hex::encode(keccak256("release-1".as_bytes()))),
    };
    schedule(
        at.saturating_add(24),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::SupportRelease(release),
            enqueued_at_ns: at.saturating_add(24),
        },
        queue,
    );
}

fn enqueue_intents(
    config: &SimRunConfigV1,
    schedule: &mut impl FnMut(u64, SimEvent, &mut BinaryHeap<ScheduledEvent>),
    queue: &mut BinaryHeap<ScheduledEvent>,
) {
    let base = 10_000_000u64;
    for i in 0..config.scenario.intent_pairs {
        let mut resting = IntentEnvelope::sample();
        resting.nonce = U256::from(10_000 + (i as u64 * 2));
        resting.side = IntentSide::Short;
        resting.limit_price_x18 = U256::from(100_000u64) * proto_types::price_x18_scale();
        resting.resign_with_sample_keys();

        let mut crossing = resting.clone();
        crossing.nonce = U256::from(10_001 + (i as u64 * 2));
        crossing.side = IntentSide::Long;
        crossing.limit_price_x18 = U256::from(101_000u64) * proto_types::price_x18_scale();
        crossing.resign_with_sample_keys();

        let t = base.saturating_add((i as u64).saturating_mul(config.scenario.intent_interval_ns));
        schedule(
            t,
            SimEvent::SubmitIntent {
                src: i % config.topology.node_count,
                intent: resting,
            },
            queue,
        );
        schedule(
            t.saturating_add(10_000),
            SimEvent::SubmitIntent {
                src: (i + 1) % config.topology.node_count,
                intent: crossing,
            },
            queue,
        );
    }
}

fn enqueue_closure_path(
    config: &SimRunConfigV1,
    schedule: &mut impl FnMut(u64, SimEvent, &mut BinaryHeap<ScheduledEvent>),
    queue: &mut BinaryHeap<ScheduledEvent>,
) {
    let base = 20_000_000u64;
    let epoch = config.scenario.closure_epoch_id;
    let ordered = (0..config.scenario.intent_pairs)
        .map(|i| format!("evt-{}", i + 1))
        .collect::<Vec<_>>();
    let snapshot_hash = format!("0x{}", hex::encode(keccak256("peerset-1".as_bytes())));
    let proposal_digest = format!("0x{}", hex::encode(keccak256("proposal-1".as_bytes())));
    let closure_hash = format!("0x{}", hex::encode(keccak256("epochclosed-1".as_bytes())));
    let peer_ids_sorted = (0..config.topology.node_count)
        .map(|i| format!("sim-node-{}", i + 1))
        .collect::<Vec<_>>();

    schedule(
        base.saturating_add(900),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::PeerSetSnapshot(PeerSetSnapshotRecord {
                region_id: config.region.region_id.clone(),
                epoch_id: epoch,
                peer_set_snapshot_hash: snapshot_hash.clone(),
                peer_ids_sorted,
            }),
            enqueued_at_ns: base.saturating_add(900),
        },
        queue,
    );

    for (i, event_id) in ordered.iter().enumerate() {
        schedule(
            base.saturating_add(i as u64),
            SimEvent::Broadcast {
                src: i % config.topology.node_count,
                msg: SimMessage::ClosureCandidate(ClosureCandidateEvent {
                    event_id: event_id.clone(),
                    emit_epoch_id: epoch,
                    receive_epoch_id: epoch,
                    event_recv_timestamp_ns: base.saturating_add(i as u64),
                    emitter_id: format!("emitter-{}", (i % config.topology.node_count) + 1),
                    slot_key: format!("slot-{}", i + 1),
                    payload_hash: format!("0x{}", hex::encode(keccak256(event_id.as_bytes()))),
                }),
                enqueued_at_ns: base.saturating_add(i as u64),
            },
            queue,
        );
    }

    schedule(
        base.saturating_add(1_000),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::ClosureProposal(ClosureProposal {
                schema_hash: String::new(),
                region_id: config.region.region_id.clone(),
                epoch_id: epoch,
                peer_set_snapshot_hash: snapshot_hash.clone(),
                parent_epoch_hash: "0x0".to_owned(),
                ordered_event_ids: ordered.clone(),
                proposer_id: "sim-node-1".to_owned(),
                proposal_nonce: 1,
                proposal_digest: proposal_digest.clone(),
                proposal_timestamp_ns: base.saturating_add(1_000),
            }),
            enqueued_at_ns: base.saturating_add(1_000),
        },
        queue,
    );
    for i in 0..config.topology.node_count {
        schedule(
            base.saturating_add(2_000 + i as u64),
            SimEvent::Broadcast {
                src: i,
                msg: SimMessage::ClosureAck(proto_types::ClosureAck {
                    schema_hash: String::new(),
                    region_id: config.region.region_id.clone(),
                    epoch_id: epoch,
                    proposal_digest: proposal_digest.clone(),
                    ack_nonce: 1,
                    ack_timestamp_ns: base.saturating_add(2_000 + i as u64),
                    acker_id: format!("sim-node-{}", i + 1),
                }),
                enqueued_at_ns: base.saturating_add(2_000 + i as u64),
            },
            queue,
        );
    }
    schedule(
        base.saturating_add(3_000),
        SimEvent::Broadcast {
            src: 0,
            msg: SimMessage::ClosureEpochClosed(ClosureEpochClosed {
                schema_hash: String::new(),
                region_id: config.region.region_id.clone(),
                epoch_id: epoch,
                peer_set_snapshot_hash: snapshot_hash,
                parent_epoch_hash: "0x0".to_owned(),
                ordered_event_ids: ordered,
                ackers: (0..config.topology.node_count)
                    .map(|i| format!("sim-node-{}", i + 1))
                    .collect(),
                closure_hash,
            }),
            enqueued_at_ns: base.saturating_add(3_000),
        },
        queue,
    );
    if config.scenario.emit_supersession {
        schedule(
            base.saturating_add(4_000),
            SimEvent::Broadcast {
                src: 0,
                msg: SimMessage::EpochSuperseded(mesh_node::api::EpochSupersededRecord {
                    schema_hash: String::new(),
                    region_id: config.region.region_id.clone(),
                    superseded_epoch_id: config.scenario.closure_epoch_id,
                    supersession_timestamp_ns: base.saturating_add(4_000),
                    supersession_hash: format!(
                        "0x{}",
                        hex::encode(keccak256("supersession-1".as_bytes()))
                    ),
                }),
                enqueued_at_ns: base.saturating_add(4_000),
            },
            queue,
        );
    }

    if config.scenario.settlement_retry_events > 0 {
        let interval = config.scenario.settlement_retry_interval_ns.max(100_000);
        for i in 0..config.scenario.settlement_retry_events {
            schedule(
                base.saturating_add(3_500)
                    .saturating_add((i as u64).saturating_mul(interval)),
                SimEvent::Broadcast {
                    src: i % config.topology.node_count,
                    msg: SimMessage::SettlementControl {
                        _retry_id: format!("retry-{}", i + 1),
                    },
                    enqueued_at_ns: base
                        .saturating_add(3_500)
                        .saturating_add((i as u64).saturating_mul(interval)),
                },
                queue,
            );
        }
    }
}

fn maybe_corrupt(rng: &mut LcgRng, link: &LinkPolicyV1, msg: SimMessage) -> (SimMessage, bool) {
    if !rng.roll_permille(link.corrupt_permille) {
        return (msg, false);
    }
    match msg {
        SimMessage::ClosureProposal(mut proposal) => {
            proposal.proposal_digest = "0xdeadbeef".to_owned();
            (SimMessage::ClosureProposal(proposal), true)
        }
        SimMessage::ClosureAck(mut ack) => {
            ack.proposal_digest = "0xdeadbeef".to_owned();
            (SimMessage::ClosureAck(ack), true)
        }
        other => (other, false),
    }
}

fn apply_message(
    config: &SimRunConfigV1,
    node: &mut SimNode,
    msg: SimMessage,
    receive_timestamp_ns: u64,
) -> Result<Option<EpochApplyOutcome>> {
    let mut epoch_apply_outcome = None::<EpochApplyOutcome>;
    match msg {
        SimMessage::Intent(intent) => {
            seed_capacity_for_intent(&mut node.runtime, &intent)?;
            let _ = node.runtime.submit_order(&intent);
        }
        SimMessage::PeerSetSnapshot(snapshot) => {
            node.runtime.set_closure_peer_set_snapshot(snapshot)
        }
        SimMessage::Pool(v) => node.runtime.observe_pool(v),
        SimMessage::PoolTerms(v) => node.runtime.observe_pool_terms(v),
        SimMessage::PoolContribution(v) => node.runtime.observe_pool_contribution(v),
        SimMessage::IntentPoolAttachment(v) => node.runtime.observe_intent_pool_attachment(v),
        SimMessage::PoolExposureAttribution(v) => node.runtime.observe_pool_exposure_attribution(v),
        SimMessage::SupportRelease(v) => node.runtime.observe_support_release(v),
        SimMessage::AuthoritySnapshot(v) => {
            let _ = node.runtime.apply_authority_snapshot_event(v)?;
        }
        SimMessage::MarkSnapshot(v) => {
            let _ = node.runtime.apply_mark_snapshot_event(v)?;
        }
        SimMessage::ClosureCandidate(v) => node.runtime.observe_closure_candidate_event(v),
        SimMessage::ClosureProposal(v) => {
            let record = ClosureProposalRecord {
                region_id: v.region_id,
                epoch_id: v.epoch_id,
                peer_set_snapshot_hash: v.peer_set_snapshot_hash,
                parent_epoch_hash: v.parent_epoch_hash,
                ordered_event_ids: v.ordered_event_ids,
                proposer_id: v.proposer_id,
                proposal_nonce: v.proposal_nonce,
                proposal_digest: v.proposal_digest,
                proposal_timestamp_ns: v.proposal_timestamp_ns,
                receive_timestamp_ns,
            };
            if let Err(reject) = node.runtime.observe_closure_proposal_typed(record) {
                node.runtime.record_reject_telemetry(
                    Some(reject.reject_code().as_u16()),
                    "ingress",
                    "closure_proposal",
                    Some(node.node_id.clone()),
                    "remote",
                );
            }
        }
        SimMessage::ClosureAck(v) => {
            let record = ClosureAckRecord {
                region_id: v.region_id,
                epoch_id: v.epoch_id,
                proposal_digest: v.proposal_digest,
                ack_nonce: v.ack_nonce,
                ack_timestamp_ns: v.ack_timestamp_ns,
                acker_id: v.acker_id,
                receive_timestamp_ns,
            };
            if let Err(reject) = node.runtime.observe_closure_ack_typed(record) {
                node.runtime.record_reject_telemetry(
                    Some(reject.reject_code().as_u16()),
                    "ingress",
                    "closure_ack",
                    Some(node.node_id.clone()),
                    "remote",
                );
            }
        }
        SimMessage::ClosureEpochClosed(v) => {
            let pre_root = node
                .runtime
                .state_machine_root_v1(&config.region.region_id)
                .ok()
                .map(|root| root.root_digest);
            let mut post_cumulative_ledger_hash = None::<String>;
            let pre_market_sequence = node.runtime.get_market_state().last_sequence;
            let pre_pool_count = pool_mutation_surface_count(&node.runtime);
            let pre_settlement_count = node
                .runtime
                .settlement_batches(None)
                .ok()
                .map(|rows| rows.len() as u64)
                .unwrap_or(0);
            let record = EpochClosedRecord {
                region_id: v.region_id,
                epoch_id: v.epoch_id,
                peer_set_snapshot_hash: v.peer_set_snapshot_hash,
                parent_epoch_hash: v.parent_epoch_hash,
                ordered_event_ids: v.ordered_event_ids,
                ackers: v.ackers,
                closure_hash: v.closure_hash,
            };
            if let Err(reject) = node.runtime.observe_epoch_closed_typed(record) {
                node.runtime.record_reject_telemetry(
                    Some(reject.reject_code().as_u16()),
                    "ingress",
                    "epoch_closed",
                    Some(node.node_id.clone()),
                    "remote",
                );
            }
            let post_root = node
                .runtime
                .state_machine_root_v1(&config.region.region_id)
                .ok()
                .map(|root| {
                    post_cumulative_ledger_hash = Some(root.cumulative_ledger_hash.clone());
                    root.root_digest
                });
            let post_market_sequence = node.runtime.get_market_state().last_sequence;
            let post_pool_count = pool_mutation_surface_count(&node.runtime);
            let post_settlement_count = node
                .runtime
                .settlement_batches(None)
                .ok()
                .map(|rows| rows.len() as u64)
                .unwrap_or(0);
            let ledger_append_time_ns =
                node.runtime
                    .store()
                    .load_ledger_epochs()
                    .ok()
                    .and_then(|rows| {
                        rows.into_iter()
                            .rev()
                            .find(|row| row.epoch.epoch_id == v.epoch_id)
                            .map(|row| row.recorded_at)
                    });
            let checkpoint_emitted =
                node.runtime
                    .store()
                    .load_ledger_checkpoints()
                    .ok()
                    .map(|rows| {
                        rows.iter()
                            .any(|row| row.checkpoint.through_epoch_id == v.epoch_id)
                    });
            epoch_apply_outcome = Some(EpochApplyOutcome {
                epoch_id: v.epoch_id,
                pre_epoch_state_root: pre_root,
                post_epoch_state_root: post_root,
                post_epoch_cumulative_ledger_hash: post_cumulative_ledger_hash,
                closure_apply_enqueue_time_ns: receive_timestamp_ns,
                closure_apply_dispatch_time_ns: receive_timestamp_ns,
                closure_apply_completion_time_ns: receive_timestamp_ns,
                market_mutation_count: post_market_sequence.saturating_sub(pre_market_sequence),
                pool_mutation_count: post_pool_count.saturating_sub(pre_pool_count),
                settlement_projection_mutation_count: post_settlement_count
                    .saturating_sub(pre_settlement_count),
                ledger_append_time_ns,
                checkpoint_eligible: v.epoch_id % 8 == 0,
                checkpoint_emitted,
            });
        }
        SimMessage::EpochSuperseded(v) => {
            if let Err(reject) = node
                .runtime
                .observe_epoch_superseded_typed(v, config.scenario.repair_depth_max.max(1))
            {
                node.runtime.record_reject_telemetry(
                    Some(reject.reject_code().as_u16()),
                    "ingress",
                    "epoch_superseded",
                    Some(node.node_id.clone()),
                    "remote",
                );
            }
        }
        SimMessage::SettlementControl { .. } => {}
    }
    // deterministic checkpoint injection cadence for replay-path exercise
    let snapshot = node.runtime.get_market_state().snapshot_hash_hex();
    let _ = node.runtime.inject_local_checkpoint(
        &config.region.region_id,
        node.runtime.get_market_state().last_sequence,
        &snapshot,
    );
    Ok(epoch_apply_outcome)
}

fn pool_mutation_surface_count(runtime: &NodeRuntime) -> u64 {
    let state = runtime.pool_runtime_state();
    (state.pools.len()
        + state.pool_terms.len()
        + state.pool_contributions.len()
        + state.intent_pool_attachments.len()
        + state.pool_exposure_attributions.len()
        + state.support_releases.len()) as u64
}

fn seed_capacity_for_intent(runtime: &mut NodeRuntime, intent: &IntentEnvelope) -> Result<()> {
    if let Some(coverage) = &intent.coverage {
        for fragment in coverage.fragments.iter().cloned() {
            let Some(signer) = sample_credit_signer_for_provider(fragment.credit_provider) else {
                continue;
            };
            let signature = signer
                .sign_hash_sync(&fragment.fragment_hash)
                .context("sign fragment hash")?;
            let _ = runtime.observe_credit_fragment(proto_types::CreditFragmentWitness {
                fragment,
                signature,
            })?;
        }
    }
    Ok(())
}

fn extract_proof_tuple(node: &mut SimNode, region_id: &str) -> Result<ProofTupleV1> {
    let closure = node.runtime.closure_proof_snapshot();
    let root = node.runtime.state_machine_root_v1(region_id)?;
    let settlement_projection_digest = node
        .runtime
        .settlement_batch_preview(256)
        .ok()
        .map(|preview| preview.deterministic_hash);
    let reject_rows = node.runtime.reject_stats(300).rows;
    let mut reject_code_multiset = BTreeMap::<String, u64>::new();
    for row in reject_rows {
        let key = format!(
            "{}:{}:{}",
            row.reject_stage,
            row.object_class,
            row.reject_code
                .map(|v| v.to_string())
                .unwrap_or_else(|| "none".to_owned())
        );
        *reject_code_multiset.entry(key).or_insert(0) += row.count_total;
    }
    Ok(ProofTupleV1 {
        node_id: node.node_id.clone(),
        accepted_epoch_ids: closure.accepted_epoch_ids.clone(),
        accepted_parent_hashes: closure.accepted_parent_hashes.clone(),
        accepted_supersession_set: closure
            .accepted_supersession_set
            .into_iter()
            .map(|s| s.supersession_hash)
            .collect(),
        final_closure_hash: closure.final_closure_hash.clone(),
        final_market_state_digest: root.market_state_digest.clone(),
        state_root_digest: root.root_digest,
        cumulative_ledger_hash: root.cumulative_ledger_hash,
        pool_state_digest: root.pool_state_digest.clone(),
        settlement_projection_digest,
        reject_code_multiset,
    })
}

fn check_pool_invariants(
    node: &SimNode,
    _proof: &ProofTupleV1,
    violations: &mut Vec<SimInvariantViolationV1>,
) {
    let state = node.runtime.pool_runtime_state();
    let mut contributions = HashMap::<String, i128>::new();
    let mut releases = HashMap::<String, i128>::new();
    let mut attributed = HashMap::<String, i128>::new();
    for c in &state.pool_contributions {
        if let Ok(v) = c.notional.parse::<i128>() {
            *contributions.entry(c.pool_id.clone()).or_insert(0) += v;
        }
    }
    for r in &state.support_releases {
        if let Ok(v) = r.released_notional.parse::<i128>() {
            *releases.entry(r.pool_id.clone()).or_insert(0) += v;
        }
    }
    for a in &state.pool_exposure_attributions {
        if let Ok(v) = a.attributed_notional.parse::<i128>() {
            *attributed.entry(a.pool_id.clone()).or_insert(0) += v;
        }
    }
    for pool in &state.pools {
        let total = pool.total_notional.parse::<i128>().unwrap_or(0);
        let reserved = pool.reserved_notional.parse::<i128>().unwrap_or(0);
        if reserved > total {
            violations.push(SimInvariantViolationV1 {
                node_id: node.node_id.clone(),
                invariant: "pool_reserved_notional_lte_total".to_owned(),
                detail: format!(
                    "pool={} reserved={} total={}",
                    pool.pool_id, reserved, total
                ),
            });
        }
        let c = contributions.get(&pool.pool_id).copied().unwrap_or(0);
        let r = releases.get(&pool.pool_id).copied().unwrap_or(0);
        let a = attributed.get(&pool.pool_id).copied().unwrap_or(0);
        if a + r > c.max(total) {
            violations.push(SimInvariantViolationV1 {
                node_id: node.node_id.clone(),
                invariant: "pool_attribution_release_conservation".to_owned(),
                detail: format!(
                    "pool={} attributed={} released={} contributions={} total={}",
                    pool.pool_id, a, r, c, total
                ),
            });
        }
    }
}

fn compile_report(
    config: &SimRunConfigV1,
    proof_tuples: Vec<ProofTupleV1>,
    invariant_violations: Vec<SimInvariantViolationV1>,
    metrics: SimMetricsV1,
    closure_epoch_traces: Vec<ClosureEpochTraceV1>,
) -> SimRunReportV1 {
    let mut closure_epoch_traces = closure_epoch_traces;
    for trace in &mut closure_epoch_traces {
        trace.authority_bucket_hash = Some(bucket_hash(&trace.authority_snapshot_ids_seen));
        trace.mark_bucket_hash = Some(bucket_hash(&trace.mark_snapshot_ids_seen));
        trace.candidate_bucket_hash = Some(bucket_hash(&trace.candidate_event_ids_seen));
        trace.settlement_retry_bucket_hash = Some(bucket_hash(&trace.settlement_retry_ids_seen));
    }
    let mut final_market_state_digest_set = proof_tuples
        .iter()
        .map(|p| p.final_market_state_digest.clone())
        .collect::<Vec<_>>();
    final_market_state_digest_set.sort();
    final_market_state_digest_set.dedup();
    let mut settlement_projection_digest_set = proof_tuples
        .iter()
        .filter_map(|p| p.settlement_projection_digest.clone())
        .collect::<Vec<_>>();
    settlement_projection_digest_set.sort();
    settlement_projection_digest_set.dedup();
    let accepted_epoch_ids = proof_tuples
        .first()
        .map(|p| p.accepted_epoch_ids.clone())
        .unwrap_or_default();
    let final_closure_hash = proof_tuples
        .first()
        .and_then(|p| p.final_closure_hash.clone());

    let mut divergence = Vec::new();
    let mut first_divergent_epoch_id = None::<u64>;
    let mut first_pre_epoch_root_split_epoch = None::<u64>;
    let mut first_post_epoch_root_split_epoch = None::<u64>;
    let mut first_root_split_class = None::<String>;
    let mut first_canonical_tuple_split_epoch = None::<u64>;
    let mut canonical_tuple_divergence_count = 0usize;
    let mut closure_apply_completion_max_skew_ns = 0u64;
    let mut closure_apply_dispatch_max_skew_ns = 0u64;
    let mut first_divergent_lane_class = None::<String>;
    let mut first_divergent_epoch_analysis = None::<FirstDivergentEpochAnalysisV1>;
    if let Some(first) = proof_tuples.first() {
        for other in proof_tuples.iter().skip(1) {
            if first.accepted_epoch_ids != other.accepted_epoch_ids {
                if first_divergent_epoch_id.is_none() {
                    first_divergent_epoch_id =
                        first_divergent_epoch(&first.accepted_epoch_ids, &other.accepted_epoch_ids);
                }
                divergence.push(format!(
                    "accepted_epoch_ids mismatch: {} vs {}",
                    first.node_id, other.node_id
                ));
            }
            if first.final_closure_hash != other.final_closure_hash {
                divergence.push(format!(
                    "final_closure_hash mismatch: {} vs {}",
                    first.node_id, other.node_id
                ));
            }
            if first.final_market_state_digest != other.final_market_state_digest {
                divergence.push(format!(
                    "final_market_state_digest mismatch: {} vs {}",
                    first.node_id, other.node_id
                ));
            }
            if first.cumulative_ledger_hash != other.cumulative_ledger_hash {
                divergence.push(format!(
                    "cumulative_ledger_hash mismatch: {} vs {}",
                    first.node_id, other.node_id
                ));
            }
            if first.pool_state_digest != other.pool_state_digest {
                divergence.push(format!(
                    "pool_state_digest mismatch: {} vs {}",
                    first.node_id, other.node_id
                ));
            }
            if first_divergent_lane_class.is_none()
                && first.reject_code_multiset != other.reject_code_multiset
            {
                first_divergent_lane_class = first_divergent_lane_from_rejects(
                    &first.reject_code_multiset,
                    &other.reject_code_multiset,
                );
            }
        }
        if first_divergent_epoch_id.is_none() && !divergence.is_empty() {
            first_divergent_epoch_id = first
                .accepted_epoch_ids
                .last()
                .copied()
                .or(Some(config.scenario.closure_epoch_id));
        }
    }
    if let Some(epoch_id) = first_divergent_epoch_id {
        first_divergent_epoch_analysis =
            analyze_first_divergent_epoch(epoch_id, &closure_epoch_traces).ok();
    }
    let mut roots_by_epoch = BTreeMap::<u64, HashSet<String>>::new();
    let mut pre_roots_by_epoch = BTreeMap::<u64, HashSet<String>>::new();
    for trace in &closure_epoch_traces {
        if let Some(root) = &trace.pre_epoch_state_root {
            pre_roots_by_epoch
                .entry(trace.epoch_id)
                .or_default()
                .insert(root.clone());
        }
        if let Some(root) = &trace.post_epoch_state_root {
            roots_by_epoch
                .entry(trace.epoch_id)
                .or_default()
                .insert(root.clone());
        }
    }
    for (epoch, roots) in &pre_roots_by_epoch {
        if *epoch >= config.scenario.closure_epoch_id {
            continue;
        }
        if roots.len() > 1 {
            first_pre_epoch_root_split_epoch = Some(*epoch);
            break;
        }
    }
    for (epoch, roots) in roots_by_epoch {
        if roots.len() > 1 {
            first_post_epoch_root_split_epoch = Some(epoch);
            break;
        }
    }
    if let Some(epoch) = first_pre_epoch_root_split_epoch.or(first_post_epoch_root_split_epoch) {
        first_root_split_class = classify_root_split_epoch(epoch, &closure_epoch_traces).ok();
    }
    let mut canonical_tuples_by_epoch = BTreeMap::<u64, HashSet<(String, String, String)>>::new();
    for trace in &closure_epoch_traces {
        let Some(epoch_closed_hash) = trace.epoch_closed_hash.clone() else {
            continue;
        };
        let Some(post_root) = trace.post_epoch_state_root.clone() else {
            continue;
        };
        let Some(post_cumulative_ledger_hash) = trace.post_epoch_cumulative_ledger_hash.clone()
        else {
            continue;
        };
        canonical_tuples_by_epoch
            .entry(trace.epoch_id)
            .or_default()
            .insert((epoch_closed_hash, post_root, post_cumulative_ledger_hash));
    }
    for (epoch, tuples) in canonical_tuples_by_epoch {
        if tuples.len() > 1 {
            canonical_tuple_divergence_count = canonical_tuple_divergence_count.saturating_add(1);
            if first_canonical_tuple_split_epoch.is_none() {
                first_canonical_tuple_split_epoch = Some(epoch);
            }
        }
    }
    let mut apply_completion_by_epoch = BTreeMap::<u64, Vec<u64>>::new();
    let mut apply_dispatch_by_epoch = BTreeMap::<u64, Vec<u64>>::new();
    for trace in &closure_epoch_traces {
        if let Some(ts) = trace.closure_apply_completion_time_ns {
            apply_completion_by_epoch
                .entry(trace.epoch_id)
                .or_default()
                .push(ts);
        }
        if let Some(ts) = trace.closure_apply_dispatch_time_ns {
            apply_dispatch_by_epoch
                .entry(trace.epoch_id)
                .or_default()
                .push(ts);
        }
    }
    for samples in apply_completion_by_epoch.values() {
        if let (Some(min), Some(max)) = (samples.iter().min(), samples.iter().max()) {
            closure_apply_completion_max_skew_ns =
                closure_apply_completion_max_skew_ns.max(max.saturating_sub(*min));
        }
    }
    for samples in apply_dispatch_by_epoch.values() {
        if let (Some(min), Some(max)) = (samples.iter().min(), samples.iter().max()) {
            closure_apply_dispatch_max_skew_ns =
                closure_apply_dispatch_max_skew_ns.max(max.saturating_sub(*min));
        }
    }
    if closure_apply_completion_max_skew_ns > config.scenario.closure_apply_skew_max_ns {
        divergence.push(format!(
            "closure_apply_completion_max_skew_ns {} exceeds allowed {}",
            closure_apply_completion_max_skew_ns, config.scenario.closure_apply_skew_max_ns
        ));
    }
    if let Some(epoch) = first_canonical_tuple_split_epoch {
        divergence.push(format!("canonical_tuple mismatch at epoch {epoch}"));
    }

    SimRunReportV1 {
        run_id: config.run_id.clone(),
        seed: config.seed,
        scenario: config.scenario.name.clone(),
        accepted_epoch_ids,
        final_closure_hash,
        final_market_state_digest_set,
        settlement_projection_digest_set,
        first_divergent_epoch_id,
        first_pre_epoch_root_split_epoch,
        first_post_epoch_root_split_epoch,
        first_root_split_class,
        first_canonical_tuple_split_epoch,
        canonical_tuple_divergence_count,
        closure_apply_completion_max_skew_ns,
        closure_apply_dispatch_max_skew_ns,
        closure_apply_skew_max_allowed_ns: config.scenario.closure_apply_skew_max_ns,
        first_divergent_lane_class,
        closure_epoch_traces,
        first_divergent_epoch_analysis,
        proof_tuples,
        metrics,
        divergence,
        invariant_violations,
    }
}

fn maybe_record_closure_publish_trace(
    nodes: &[SimNode],
    src: usize,
    publish_time_ns: u64,
    enqueue_time_ns: u64,
    msg: &SimMessage,
    in_flight_by_lane: &BTreeMap<String, usize>,
    traces: &mut BTreeMap<(String, u64), ClosureEpochTraceV1>,
) {
    let Some((epoch_id, node_id)) = closure_epoch_trace_key(nodes, src, msg) else {
        return;
    };
    let closure_queue_depth = in_flight_by_lane
        .get("closure_control")
        .copied()
        .unwrap_or(0);
    let settlement_queue_depth = in_flight_by_lane
        .get("settlement_control")
        .copied()
        .unwrap_or(0);
    let trace = traces
        .entry((node_id.clone(), epoch_id))
        .or_insert_with(|| ClosureEpochTraceV1 {
            node_id,
            epoch_id,
            ..ClosureEpochTraceV1::default()
        });
    match msg {
        SimMessage::ClosureProposal(v) => {
            trace.proposer_id = Some(v.proposer_id.clone());
            trace.proposal_digest = Some(v.proposal_digest.clone());
            trace.proposal_ordered_event_ids = v.ordered_event_ids.clone();
            trace
                .proposal_enqueue_time_ns
                .get_or_insert(enqueue_time_ns);
            trace
                .proposal_publish_time_ns
                .get_or_insert(publish_time_ns);
            trace.proposal_publish_closure_queue_depth = closure_queue_depth;
            trace.proposal_publish_settlement_queue_depth = settlement_queue_depth;
        }
        SimMessage::ClosureAck(_) => {
            trace.ack_enqueue_time_ns.get_or_insert(enqueue_time_ns);
            trace.ack_publish_time_ns.get_or_insert(publish_time_ns);
            trace.ack_publish_closure_queue_depth = closure_queue_depth;
            trace.ack_publish_settlement_queue_depth = settlement_queue_depth;
            trace.quorum_threshold = ((nodes.len() as u64).saturating_add(1)) / 2;
        }
        SimMessage::ClosureEpochClosed(v) => {
            if trace.quorum_threshold == 0 {
                trace.quorum_threshold = ((nodes.len() as u64).saturating_add(1)) / 2;
            }
            trace
                .epoch_closed_enqueue_time_ns
                .get_or_insert(enqueue_time_ns);
            trace
                .epoch_closed_publish_time_ns
                .get_or_insert(publish_time_ns);
            trace.epoch_closed_publish_closure_queue_depth = closure_queue_depth;
            trace.epoch_closed_publish_settlement_queue_depth = settlement_queue_depth;
            trace.epoch_closed_hash = Some(v.closure_hash.clone());
            if trace.epoch_closed_ackers.is_empty() {
                trace.epoch_closed_ackers = v.ackers.clone();
            }
            let mut canonical_ackers = v.ackers.clone();
            canonical_ackers.sort();
            canonical_ackers.dedup();
            trace.frozen_quorum_members = canonical_ackers
                .into_iter()
                .take(trace.quorum_threshold as usize)
                .collect();
        }
        _ => {}
    }
}

fn maybe_record_closure_receive_trace(
    nodes: &[SimNode],
    dst: usize,
    receive_time_ns: u64,
    msg: &SimMessage,
    traces: &mut BTreeMap<(String, u64), ClosureEpochTraceV1>,
) {
    let Some((epoch_id, node_id)) = closure_epoch_trace_key(nodes, dst, msg) else {
        return;
    };
    let trace = traces
        .entry((node_id.clone(), epoch_id))
        .or_insert_with(|| ClosureEpochTraceV1 {
            node_id,
            epoch_id,
            ..ClosureEpochTraceV1::default()
        });
    match msg {
        SimMessage::ClosureProposal(v) => {
            trace.proposer_id = Some(v.proposer_id.clone());
            trace.proposal_digest = Some(v.proposal_digest.clone());
            trace.proposal_ordered_event_ids = v.ordered_event_ids.clone();
            match trace.proposal_receive_time_ns {
                Some(existing) => {
                    trace.proposal_receive_time_ns = Some(existing.min(receive_time_ns))
                }
                None => trace.proposal_receive_time_ns = Some(receive_time_ns),
            }
        }
        SimMessage::ClosureAck(v) => {
            match trace.ack_receive_time_ns {
                Some(existing) => trace.ack_receive_time_ns = Some(existing.min(receive_time_ns)),
                None => trace.ack_receive_time_ns = Some(receive_time_ns),
            }
            let entry = trace
                .ack_arrival_by_acker_ns
                .entry(v.acker_id.clone())
                .or_insert(receive_time_ns);
            *entry = (*entry).min(receive_time_ns);
            trace.quorum_threshold = ((nodes.len() as u64).saturating_add(1)) / 2;
            if trace.quorum_reached_time_ns.is_none()
                && trace.ack_arrival_by_acker_ns.len() as u64 >= trace.quorum_threshold
            {
                trace.quorum_reached_time_ns = Some(receive_time_ns);
                if trace.frozen_quorum_members.is_empty() {
                    let mut arrivals = trace
                        .ack_arrival_by_acker_ns
                        .iter()
                        .map(|(acker, ts)| (*ts, acker.as_str()))
                        .collect::<Vec<_>>();
                    arrivals.sort_unstable();
                    trace.frozen_quorum_members = arrivals
                        .into_iter()
                        .take(trace.quorum_threshold as usize)
                        .map(|(_, acker)| acker.to_owned())
                        .collect();
                }
            }
        }
        SimMessage::ClosureEpochClosed(v) => {
            if trace.quorum_threshold == 0 {
                trace.quorum_threshold = ((nodes.len() as u64).saturating_add(1)) / 2;
            }
            match trace.epoch_closed_receive_time_ns {
                Some(existing) => {
                    trace.epoch_closed_receive_time_ns = Some(existing.min(receive_time_ns))
                }
                None => trace.epoch_closed_receive_time_ns = Some(receive_time_ns),
            }
            trace.epoch_closed_hash = Some(v.closure_hash.clone());
            if trace.epoch_closed_ackers.is_empty() {
                trace.epoch_closed_ackers = v.ackers.clone();
            }
            if trace.quorum_threshold > 0 {
                let mut canonical_ackers = v.ackers.clone();
                canonical_ackers.sort();
                canonical_ackers.dedup();
                trace.frozen_quorum_members = canonical_ackers
                    .into_iter()
                    .take(trace.quorum_threshold as usize)
                    .collect();
            }
        }
        _ => {}
    }
}

fn maybe_record_closure_apply_trace(
    nodes: &[SimNode],
    dst: usize,
    outcome: EpochApplyOutcome,
    traces: &mut BTreeMap<(String, u64), ClosureEpochTraceV1>,
) {
    let Some(node) = nodes.get(dst) else {
        return;
    };
    let trace = traces
        .entry((node.node_id.clone(), outcome.epoch_id))
        .or_insert_with(|| ClosureEpochTraceV1 {
            node_id: node.node_id.clone(),
            epoch_id: outcome.epoch_id,
            ..ClosureEpochTraceV1::default()
        });
    trace.pre_epoch_state_root = outcome.pre_epoch_state_root;
    trace.post_epoch_state_root = outcome.post_epoch_state_root;
    trace.post_epoch_cumulative_ledger_hash = outcome.post_epoch_cumulative_ledger_hash;
    trace
        .closure_apply_enqueue_time_ns
        .get_or_insert(outcome.closure_apply_enqueue_time_ns);
    trace
        .closure_apply_dispatch_time_ns
        .get_or_insert(outcome.closure_apply_dispatch_time_ns);
    trace
        .closure_apply_completion_time_ns
        .get_or_insert(outcome.closure_apply_completion_time_ns);
    trace.market_mutation_count = trace
        .market_mutation_count
        .saturating_add(outcome.market_mutation_count);
    trace.pool_mutation_count = trace
        .pool_mutation_count
        .saturating_add(outcome.pool_mutation_count);
    trace.settlement_projection_mutation_count = trace
        .settlement_projection_mutation_count
        .saturating_add(outcome.settlement_projection_mutation_count);
    trace.ledger_append_time_ns = outcome.ledger_append_time_ns;
    trace.checkpoint_eligible = Some(outcome.checkpoint_eligible);
    trace.checkpoint_emitted = outcome.checkpoint_emitted;
}

fn maybe_record_epoch_input_observation(
    config: &SimRunConfigV1,
    nodes: &[SimNode],
    dst: usize,
    receive_time_ns: u64,
    msg: &SimMessage,
    traces: &mut BTreeMap<(String, u64), ClosureEpochTraceV1>,
) {
    let Some(node) = nodes.get(dst) else {
        return;
    };
    let epoch_id = match msg {
        SimMessage::ClosureCandidate(v) => match config.region.event_epoch_assignment_source {
            EventEpochAssignmentSource::EmitTimestamp => v.emit_epoch_id,
            EventEpochAssignmentSource::ReceiveTimestamp => v.receive_epoch_id,
        },
        SimMessage::ClosureProposal(v) => v.epoch_id,
        SimMessage::ClosureAck(v) => v.epoch_id,
        SimMessage::ClosureEpochClosed(v) => v.epoch_id,
        SimMessage::AuthoritySnapshot(_)
        | SimMessage::MarkSnapshot(_)
        | SimMessage::SettlementControl { .. } => config.scenario.closure_epoch_id,
        _ => return,
    };
    let trace = traces
        .entry((node.node_id.clone(), epoch_id))
        .or_insert_with(|| ClosureEpochTraceV1 {
            node_id: node.node_id.clone(),
            epoch_id,
            ..ClosureEpochTraceV1::default()
        });
    match msg {
        SimMessage::AuthoritySnapshot(v) => {
            if !trace
                .authority_snapshot_ids_seen
                .iter()
                .any(|id| id == &v.snapshot_id)
            {
                trace
                    .authority_snapshot_ids_seen
                    .push(v.snapshot_id.clone());
            }
        }
        SimMessage::MarkSnapshot(v) => {
            let id = format!("{}@{}", v.snapshot_id, v.timestamp_ns);
            if !trace.mark_snapshot_ids_seen.iter().any(|cur| cur == &id) {
                trace.mark_snapshot_ids_seen.push(id);
            }
        }
        SimMessage::ClosureCandidate(v) => {
            if !trace
                .candidate_event_ids_seen
                .iter()
                .any(|id| id == &v.event_id)
            {
                trace.candidate_event_ids_seen.push(v.event_id.clone());
            }
        }
        SimMessage::SettlementControl {
            _retry_id: retry_id,
        } => {
            if !trace
                .settlement_retry_ids_seen
                .iter()
                .any(|id| id == retry_id)
            {
                trace.settlement_retry_ids_seen.push(retry_id.clone());
            }
            if trace.closure_apply_enqueue_time_ns.is_none() {
                trace.closure_apply_enqueue_time_ns = Some(receive_time_ns);
            }
        }
        _ => {}
    }
}

fn closure_epoch_trace_key(
    nodes: &[SimNode],
    idx: usize,
    msg: &SimMessage,
) -> Option<(u64, String)> {
    let epoch = match msg {
        SimMessage::ClosureProposal(v) => v.epoch_id,
        SimMessage::ClosureAck(v) => v.epoch_id,
        SimMessage::ClosureEpochClosed(v) => v.epoch_id,
        _ => return None,
    };
    Some((epoch, nodes.get(idx)?.node_id.clone()))
}

fn analyze_first_divergent_epoch(
    epoch_id: u64,
    traces: &[ClosureEpochTraceV1],
) -> Result<FirstDivergentEpochAnalysisV1> {
    let mut proposer_ids = traces
        .iter()
        .filter(|t| t.epoch_id == epoch_id)
        .filter_map(|t| t.proposer_id.clone())
        .collect::<Vec<_>>();
    proposer_ids.sort();
    proposer_ids.dedup();

    let mut proposal_digests = traces
        .iter()
        .filter(|t| t.epoch_id == epoch_id)
        .filter_map(|t| t.proposal_digest.clone())
        .collect::<Vec<_>>();
    proposal_digests.sort();
    proposal_digests.dedup();

    let mut epoch_closed_hashes = traces
        .iter()
        .filter(|t| t.epoch_id == epoch_id)
        .filter_map(|t| t.epoch_closed_hash.clone())
        .collect::<Vec<_>>();
    epoch_closed_hashes.sort();
    epoch_closed_hashes.dedup();

    let mut ack_set_hashes = Vec::<String>::new();
    let mut frozen_quorum_member_sets = Vec::<Vec<String>>::new();
    for t in traces.iter().filter(|t| t.epoch_id == epoch_id) {
        if t.epoch_closed_ackers.is_empty() {
            continue;
        }
        let mut ackers = t.epoch_closed_ackers.clone();
        ackers.sort();
        let bytes = serde_json::to_vec(&ackers).context("serialize ackers")?;
        ack_set_hashes.push(format!("0x{}", hex::encode(keccak256(bytes))));
        if !t.frozen_quorum_members.is_empty() {
            let mut frozen = t.frozen_quorum_members.clone();
            frozen.sort();
            frozen_quorum_member_sets.push(frozen);
        }
    }
    ack_set_hashes.sort();
    ack_set_hashes.dedup();
    frozen_quorum_member_sets.sort();
    frozen_quorum_member_sets.dedup();

    let ack_set_mismatch = ack_set_hashes.len() > 1;
    let timing_only_split =
        !ack_set_mismatch && proposal_digests.len() == 1 && epoch_closed_hashes.len() <= 1;

    Ok(FirstDivergentEpochAnalysisV1 {
        epoch_id,
        proposer_ids,
        proposal_digests,
        epoch_closed_hashes,
        ack_set_hashes,
        frozen_quorum_member_sets,
        ack_set_mismatch,
        timing_only_split,
    })
}

fn classify_root_split_epoch(epoch_id: u64, traces: &[ClosureEpochTraceV1]) -> Result<String> {
    let rows = traces
        .iter()
        .filter(|t| t.epoch_id == epoch_id)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return Ok("unknown".to_owned());
    }
    let mut root_set = HashSet::<String>::new();
    for row in &rows {
        if let Some(root) = row.post_epoch_state_root.as_ref() {
            root_set.insert(root.clone());
        }
    }
    if root_set.len() <= 1 {
        return Ok("none".to_owned());
    }

    let mut closure_hashes = HashSet::<String>::new();
    for row in &rows {
        if let Some(hash) = row.epoch_closed_hash.as_ref() {
            closure_hashes.insert(hash.clone());
        }
    }
    if closure_hashes.len() > 1 {
        return Ok("C".to_owned());
    }

    let mut auth = HashSet::<String>::new();
    let mut mark = HashSet::<String>::new();
    let mut candidate = HashSet::<String>::new();
    let mut settle = HashSet::<String>::new();
    for row in &rows {
        if let Some(v) = row.authority_bucket_hash.as_ref() {
            auth.insert(v.clone());
        }
        if let Some(v) = row.mark_bucket_hash.as_ref() {
            mark.insert(v.clone());
        }
        if let Some(v) = row.candidate_bucket_hash.as_ref() {
            candidate.insert(v.clone());
        }
        if let Some(v) = row.settlement_retry_bucket_hash.as_ref() {
            settle.insert(v.clone());
        }
    }
    let buckets_same =
        auth.len() <= 1 && mark.len() <= 1 && candidate.len() <= 1 && settle.len() <= 1;
    if buckets_same {
        Ok("A".to_owned())
    } else {
        Ok("B".to_owned())
    }
}

fn bucket_hash(values: &[String]) -> String {
    let mut rows = values.to_vec();
    rows.sort();
    rows.dedup();
    let bytes = serde_json::to_vec(&rows).unwrap_or_default();
    format!("0x{}", hex::encode(keccak256(bytes)))
}

fn write_report(report: &SimRunReportV1, workspace_root: &Path, out: &str) -> Result<()> {
    let path = workspace_root.join(out);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("create {}", parent.display()))?;
    }
    let bytes = serde_json::to_vec_pretty(report).context("serialize sim report")?;
    fs::write(&path, bytes).with_context(|| format!("write {}", path.display()))?;
    Ok(())
}

fn is_partitioned(at_ns: u64, _src: usize, _dst: usize, windows: &[PartitionWindowV1]) -> bool {
    windows
        .iter()
        .any(|w| at_ns >= w.from_ns && at_ns < w.to_ns)
}

fn message_class(msg: &SimMessage) -> &'static str {
    match msg {
        SimMessage::Intent(_) => "intent",
        SimMessage::PeerSetSnapshot(_) => "peer_set_snapshot",
        SimMessage::Pool(_) => "pool",
        SimMessage::PoolTerms(_) => "pool_terms",
        SimMessage::PoolContribution(_) => "pool_contribution",
        SimMessage::IntentPoolAttachment(_) => "intent_pool_attachment",
        SimMessage::PoolExposureAttribution(_) => "pool_exposure_attribution",
        SimMessage::SupportRelease(_) => "support_release",
        SimMessage::AuthoritySnapshot(_) => "authority_snapshot",
        SimMessage::MarkSnapshot(_) => "mark_snapshot",
        SimMessage::ClosureCandidate(_) => "closure_candidate",
        SimMessage::ClosureProposal(_) => "closure_proposal",
        SimMessage::ClosureAck(_) => "closure_ack",
        SimMessage::ClosureEpochClosed(_) => "closure_epoch_closed",
        SimMessage::EpochSuperseded(_) => "epoch_superseded",
        SimMessage::SettlementControl { .. } => "settlement_control",
    }
}

fn message_lane_class(msg: &SimMessage) -> &'static str {
    match msg {
        SimMessage::Intent(_) => "market_critical",
        SimMessage::PeerSetSnapshot(_)
        | SimMessage::ClosureCandidate(_)
        | SimMessage::ClosureProposal(_)
        | SimMessage::ClosureAck(_)
        | SimMessage::ClosureEpochClosed(_)
        | SimMessage::EpochSuperseded(_) => "closure_control",
        SimMessage::Pool(_)
        | SimMessage::PoolTerms(_)
        | SimMessage::PoolContribution(_)
        | SimMessage::IntentPoolAttachment(_)
        | SimMessage::PoolExposureAttribution(_)
        | SimMessage::SupportRelease(_) => "pool_support",
        SimMessage::AuthoritySnapshot(_) | SimMessage::MarkSnapshot(_) => "sync_control",
        SimMessage::SettlementControl { .. } => "settlement_control",
    }
}

fn lane_priority(lane: &str) -> u8 {
    match lane {
        "closure_control" => 0,
        "market_critical" => 1,
        "pool_support" => 2,
        "settlement_control" => 3,
        "sync_control" => 4,
        _ => 5,
    }
}

fn scheduled_event_priority(event: &SimEvent) -> u8 {
    match event {
        SimEvent::Broadcast { msg, .. } | SimEvent::Deliver { msg, .. } => {
            lane_priority(message_lane_class(msg))
        }
        SimEvent::SubmitIntent { .. } => lane_priority("market_critical"),
        SimEvent::ExtractCheckpoint => lane_priority("sync_control"),
    }
}

fn first_divergent_epoch(a: &[u64], b: &[u64]) -> Option<u64> {
    let common = a.len().min(b.len());
    for i in 0..common {
        if a[i] != b[i] {
            return Some(a[i].min(b[i]));
        }
    }
    a.get(common).copied().or_else(|| b.get(common).copied())
}

fn first_divergent_lane_from_rejects(
    a: &BTreeMap<String, u64>,
    b: &BTreeMap<String, u64>,
) -> Option<String> {
    let mut keys = a.keys().chain(b.keys()).cloned().collect::<Vec<_>>();
    keys.sort();
    keys.dedup();
    for key in keys {
        let av = a.get(&key).copied().unwrap_or(0);
        let bv = b.get(&key).copied().unwrap_or(0);
        if av == bv {
            continue;
        }
        let mut parts = key.split(':');
        let _stage = parts.next();
        let object = parts.next().unwrap_or("sync_control");
        let lane = match object {
            "closure_proposal" | "closure_ack" | "epoch_closed" | "epoch_superseded" => {
                "closure_control"
            }
            "intent" | "order" | "fill_report" | "fill_ack" => "market_critical",
            "pool"
            | "pool_terms"
            | "pool_contribution"
            | "intent_pool_attachment"
            | "pool_exposure_attribution"
            | "support_release" => "pool_support",
            "settlement_control" | "settlement_batch" => "settlement_control",
            _ => "sync_control",
        };
        return Some(lane.to_owned());
    }
    None
}

fn summarize_latency(mut samples: Vec<u64>) -> LatencySummaryV1 {
    if samples.is_empty() {
        return LatencySummaryV1::default();
    }
    samples.sort_unstable();
    let count = samples.len();
    let p50 = samples[(count - 1) * 50 / 100];
    let p95 = samples[(count - 1) * 95 / 100];
    LatencySummaryV1 {
        count,
        min_ns: samples.first().copied(),
        p50_ns: Some(p50),
        p95_ns: Some(p95),
        max_ns: samples.last().copied(),
    }
}
