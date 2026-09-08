use anyhow::Result;
use clap::Parser;
use colored::*;
use log::info;
use std::fs::File;
use std::io::Write;
use chrono::Local;

mod config;
mod report;
mod scanners;

use report::Report;
use scanners::{Scanner, process, network, filesystem, nix};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    full: bool,

    #[arg(short, long)]
    verbose: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();
    
    let env = env_logger::Env::default().filter_or("RUST_LOG", if args.verbose { "debug" } else { "info" });
    env_logger::init_from_env(env);

    println!("{}", "\n🛡️  NastyTechLords Security Audit 🛡️".green().bold());
    println!("{}", "======================================".blue());

    let mut report = Report::new();

    if let Err(e) = process::ProcessScanner.scan(&mut report, &args) {
        println!("{} Process scan failed: {}", "ERROR:".red(), e);
    }

    if let Err(e) = network::NetworkScanner.scan(&mut report, &args) {
         println!("{} Network scan failed: {}", "ERROR:".red(), e);
    }

    if let Err(e) = filesystem::FsScanner.scan(&mut report, &args) {
         println!("{} Filesystem scan failed: {}", "ERROR:".red(), e);
    }

    if let Err(e) = scanners::privacy::PrivacyScanner.scan(&mut report, &args) {
         println!("{} Privacy scan failed: {}", "ERROR:".red(), e);
    }

    if let Err(e) = nix::NixScanner.scan(&mut report, &args) {
         println!("{} Nix scan failed: {}", "ERROR:".red(), e);
    }

    report.print_summary();
    save_report(&report)?;

    if report.has_critical() {
        std::process::exit(2);
    }
    Ok(())
}

fn save_report(report: &Report) -> Result<()> {
    let timestamp = Local::now().format("%Y%m%d-%H%M%S");
    let filename = format!("/var/log/nastyTechLords/audit-{}.log", timestamp);
    let latest_link = "/var/log/nastyTechLords/latest-summary.txt";
    
    let effective_path = if std::fs::metadata("/var/log/nastyTechLords").is_ok() {
        filename
    } else {
        format!("/tmp/ntl-audit-{}.log", timestamp)
    };

    let mut file = File::create(&effective_path)?;
    write!(file, "{}", report.generate_text_log())?;
    
    if effective_path.starts_with("/var/log") {
        let _ = std::fs::remove_file(latest_link);
        let _ = std::os::unix::fs::symlink(&effective_path, latest_link);
    }

    info!("Report saved to: {}", effective_path);
    Ok(())
}
