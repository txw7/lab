use std::path::PathBuf;

use anyhow::{Context, Result};
use sim_lab::{load_config, run};

fn main() -> Result<()> {
    let mut args = std::env::args().skip(1);
    let Some(config_path) = args.next() else {
        anyhow::bail!("usage: sim_lab <config_path>");
    };
    let config_path = PathBuf::from(config_path);
    let workspace_root = std::env::current_dir().context("resolve current_dir")?;
    let config = load_config(&config_path)?;
    let report = run(config, &workspace_root)?;
    println!(
        "{{\"run_id\":\"{}\",\"scenario\":\"{}\",\"divergence_count\":{},\"invariant_violation_count\":{}}}",
        report.run_id,
        report.scenario,
        report.divergence.len(),
        report.invariant_violations.len()
    );
    Ok(())
}
