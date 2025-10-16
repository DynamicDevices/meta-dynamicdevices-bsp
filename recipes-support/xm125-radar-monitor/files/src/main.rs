use clap::{Arg, Command};
use std::process;

fn main() {
    let matches = Command::new("xm125-radar-monitor")
        .version("1.1.0")
        .author("Alex J Lennon <ajlennon@dynamicdevices.co.uk>")
        .about("Production CLI tool for Acconeer XM125 radar modules")
        .arg(
            Arg::new("mode")
                .short('m')
                .long("mode")
                .value_name("MODE")
                .help("Sets the radar mode (distance, presence, breathing)")
                .required(false)
                .default_value("distance"),
        )
        .arg(
            Arg::new("config")
                .short('c')
                .long("config")
                .value_name("FILE")
                .help("Sets a custom config file")
                .required(false),
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .help("Enable verbose output")
                .action(clap::ArgAction::SetTrue),
        )
        .get_matches();

    let mode = matches.get_one::<String>("mode").unwrap();
    let verbose = matches.get_flag("verbose");

    if verbose {
        println!("XM125 Radar Monitor v1.1.0");
        println!("Mode: {}", mode);
    }

    // TODO: Implement actual radar functionality
    // This is a stub implementation for build testing
    println!("XM125 Radar Monitor - Stub Implementation");
    println!("Mode: {}", mode);
    
    if let Some(config_file) = matches.get_one::<String>("config") {
        println!("Config file: {}", config_file);
    }

    // Simulate successful operation
    println!("Radar monitoring started successfully (stub)");
    
    // Exit successfully
    process::exit(0);
}
