use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Output, Stdio};

type TaskResult<T> = Result<T, String>;

enum Task {
    Typecheck,
    Fixtures,
    Package,
    Help,
}

impl Task {
    fn parse(value: Option<&str>) -> TaskResult<Self> {
        match value {
            Some("typecheck") => Ok(Self::Typecheck),
            Some("fixtures") => Ok(Self::Fixtures),
            Some("package") => Ok(Self::Package),
            None | Some("--help" | "help") => Ok(Self::Help),
            Some(value) => Err(format!("Unknown task: {value}")),
        }
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("Walk check failed: {error}");
        std::process::exit(1);
    }
}

fn run() -> TaskResult<()> {
    let arguments: Vec<String> = env::args().skip(1).collect();
    if arguments.len() > 1 {
        return Err("Expected one task; use --help.".into());
    }
    match Task::parse(arguments.first().map(String::as_str))? {
        Task::Typecheck => typecheck(),
        Task::Fixtures => fixtures(),
        Task::Package => package(),
        Task::Help => {
            println!("walk-tools <typecheck|fixtures|package>");
            Ok(())
        }
    }
}

fn execute(program: &str, arguments: &[&str]) -> TaskResult<Output> {
    Command::new(program)
        .args(arguments)
        .output()
        .map_err(|error| format!("Start {program}: {error}"))
}

fn diagnostics(output: &Output) -> String {
    format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    )
}

fn has_engine_error(log: &str) -> bool {
    log.lines().any(|line| {
        line.contains("ERROR:") || line.contains("Parse Error:") || line.contains("SCRIPT ERROR:")
    })
}

fn successful(output: Output, operation: &str) -> TaskResult<()> {
    let log = diagnostics(&output);
    if !output.status.success() || has_engine_error(&log) {
        return Err(format!("{operation}:\n{log}"));
    }
    Ok(())
}

fn typecheck() -> TaskResult<()> {
    successful(
        execute(
            "godot",
            &[
                "--headless",
                "--editor",
                "--path",
                ".",
                "--import",
                "--quit",
                "--quiet",
            ],
        )?,
        "Import and compile the project",
    )?;
    println!("Godot imported and compiled the project without errors.");
    Ok(())
}

fn fixtures() -> TaskResult<()> {
    fs::create_dir_all("build/type-fixtures").map_err(|error| error.to_string())?;
    fs::write("build/.gdignore", "").map_err(|error| error.to_string())?;
    let cases = [
        (
            "valid",
            "extends SceneTree\nfunc _initialize() -> void:\n\tquit()\n",
            true,
        ),
        (
            "wrong_type",
            "extends SceneTree\nfunc broken() -> int:\n\treturn \"wrong\"\n",
            false,
        ),
        (
            "missing_return_type",
            "extends SceneTree\nfunc broken():\n\treturn 1\n",
            false,
        ),
        (
            "missing_parameter_type",
            "extends SceneTree\nfunc broken(value) -> int:\n\treturn int(value)\n",
            false,
        ),
    ];
    for (name, source, valid) in cases {
        let path = format!("build/type-fixtures/{name}.gd");
        fs::write(&path, source).map_err(|error| error.to_string())?;
        let output = execute(
            "godot",
            &[
                "--headless",
                "--path",
                ".",
                "--check-only",
                "--script",
                &path,
            ],
        )?;
        let log = diagnostics(&output);
        let accepted = output.status.success() && !has_engine_error(&log);
        if accepted != valid || !valid && !log.contains("Parse Error:") {
            return Err(format!("Unexpected compiler verdict for {name}:\n{log}"));
        }
    }
    println!("Godot accepted typed code and rejected wrong and missing types.");
    Ok(())
}

fn copy_tree(source: &Path, destination: &Path) -> TaskResult<()> {
    fs::create_dir_all(destination).map_err(|error| error.to_string())?;
    for entry in fs::read_dir(source).map_err(|error| error.to_string())? {
        let entry = entry.map_err(|error| error.to_string())?;
        let target = destination.join(entry.file_name());
        if entry
            .file_type()
            .map_err(|error| error.to_string())?
            .is_dir()
        {
            copy_tree(&entry.path(), &target)?;
        } else {
            fs::copy(entry.path(), target).map_err(|error| error.to_string())?;
        }
    }
    Ok(())
}

fn companion_documents(destination: &Path) -> TaskResult<()> {
    fs::create_dir_all(destination).map_err(|error| error.to_string())?;
    fs::copy("docs/playing.md", destination.join("README.md"))
        .map_err(|error| error.to_string())?;
    for source in ["THIRD_PARTY_NOTICES.md", "LICENSE-MIT", "LICENSE-APACHE"] {
        fs::copy(source, destination.join(source))
            .map_err(|error| format!("Copy {source}: {error}"))?;
    }
    copy_tree(Path::new("assets/licenses"), &destination.join("licenses"))?;
    fs::copy(
        "addons/gut/LICENSE.md",
        destination.join("licenses/GUT-LICENSE.md"),
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn package() -> TaskResult<()> {
    let tar = if cfg!(windows) { "tar" } else { "bsdtar" };
    for platform in ["windows", "linux"] {
        companion_documents(&Path::new("build").join(platform))?;
    }
    fs::create_dir_all("build/macos-package").map_err(|error| error.to_string())?;
    successful(
        execute(
            tar,
            &["-xf", "build/macos/Walk.zip", "-C", "build/macos-package"],
        )?,
        "Extract the macOS app",
    )?;
    companion_documents(Path::new("build/macos-package"))?;
    let archives = [
        ("zip", "build/Walk-windows-x86_64.zip", "build/windows"),
        (
            "zip",
            "build/Walk-macos-universal.zip",
            "build/macos-package",
        ),
        ("gzip", "build/Walk-linux-x86_64.tar.gz", "build/linux"),
    ];
    for (format, target, directory) in archives {
        let arguments = if format == "zip" {
            vec![
                "--no-xattrs",
                "--format=zip",
                "-cf",
                target,
                "-C",
                directory,
                ".",
            ]
        } else {
            vec!["--no-xattrs", "-czf", target, "-C", directory, "."]
        };
        successful(execute(tar, &arguments)?, "Archive the desktop package")?;
    }
    let files = execute(
        "git",
        &[
            "ls-files",
            "-co",
            "--deduplicate",
            "--exclude-standard",
            "-z",
        ],
    )?;
    if !files.status.success() || files.stdout.is_empty() {
        return Err("Read the editable project file list.".into());
    }
    let mut archive = Command::new(tar)
        .args([
            "--no-xattrs",
            "--format=zip",
            "-cf",
            "build/Walk-project.zip",
            "--null",
            "-T",
            "-",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| error.to_string())?;
    let mut input = archive.stdin.take().ok_or("Open the archive input.")?;
    input
        .write_all(&files.stdout)
        .map_err(|error| error.to_string())?;
    drop(input);
    successful(
        archive
            .wait_with_output()
            .map_err(|error| error.to_string())?,
        "Archive the editable project",
    )?;
    println!("Prepared the editable project and three desktop packages in build/.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_tasks_are_refused() {
        assert!(Task::parse(Some("publish")).is_err());
        assert!(matches!(
            Task::parse(Some("typecheck")),
            Ok(Task::Typecheck)
        ));
    }

    #[test]
    fn editor_errors_fail_even_with_a_success_exit_status() {
        assert!(has_engine_error("SCRIPT ERROR: Parse Error: Invalid type"));
        assert!(has_engine_error("ERROR: Failed loading resource"));
        assert!(!has_engine_error("Godot Engine v4.7.2\nAll checks passed."));
    }
}
