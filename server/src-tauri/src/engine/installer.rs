use std::{
    fs,
    io::{Cursor, Read},
    path::{Path, PathBuf},
};

use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, USER_AGENT};
use serde::Deserialize;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum InstallerError {
    #[error("http error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("zip error: {0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("no compatible Stockfish release asset was found for this platform")]
    NoCompatibleAsset,
    #[error("downloaded archive did not contain a Stockfish executable")]
    MissingExecutable,
    #[error("{0}")]
    Message(String),
}

#[derive(Debug, Deserialize)]
struct GithubRelease {
    tag_name: String,
    assets: Vec<GithubAsset>,
}

#[derive(Debug, Deserialize, Clone)]
struct GithubAsset {
    name: String,
    browser_download_url: String,
}

fn ensure_dir(path: &std::path::Path) -> std::io::Result<()> {
    std::fs::create_dir_all(path)
}

pub fn stockfish_install_dir() -> Result<PathBuf, InstallerError> {
    let dirs =
        directories::ProjectDirs::from("local", "", "roblox-chess-script").ok_or_else(|| {
            InstallerError::Message("Could not find the app data directory.".to_string())
        })?;

    let dir = dirs.data_dir().join("engines").join("stockfish");

    fs::create_dir_all(&dir)?;

    Ok(dir)
}

pub fn install_manual_stockfish(source: &Path, data_dir: &Path) -> Result<PathBuf, InstallerError> {
    validate_stockfish_path(source)?;

    let install_dir = data_dir.join("engines").join("stockfish");
    fs::create_dir_all(&install_dir)?;

    let file_name = source.file_name().ok_or_else(|| {
        InstallerError::Message("The selected file has no file name.".to_string())
    })?;

    let destination = install_dir.join(file_name);

    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::copy(source, &destination)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;

        let mut permissions = fs::metadata(&destination)?.permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&destination, permissions)?;
    }

    Ok(destination)
}
pub fn find_existing_stockfish(data_dir: &Path) -> Result<Option<PathBuf>, InstallerError> {
    let install_dir = data_dir.join("engines").join("stockfish");

    if let Some(path) = find_stockfish_executable(&install_dir) {
        return Ok(Some(path));
    }

    #[cfg(target_os = "windows")]
    {
        let common_paths = [
            PathBuf::from("C:\\stockfish\\stockfish.exe"),
            PathBuf::from("C:\\Program Files\\Stockfish\\stockfish.exe"),
            PathBuf::from("C:\\Program Files (x86)\\Stockfish\\stockfish.exe"),
        ];

        for path in common_paths {
            if is_probably_stockfish(&path) {
                return Ok(Some(path));
            }
        }

        if let Some(path_env) = std::env::var_os("PATH") {
            for dir in std::env::split_paths(&path_env) {
                let candidate = dir.join("stockfish.exe");

                if is_probably_stockfish(&candidate) {
                    return Ok(Some(candidate));
                }
            }
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        if let Some(path_env) = std::env::var_os("PATH") {
            for dir in std::env::split_paths(&path_env) {
                let candidate = dir.join("stockfish");

                if is_probably_stockfish(&candidate) {
                    return Ok(Some(candidate));
                }
            }
        }
    }

    Ok(None)
}

pub async fn redownload_latest_stockfish(data_dir: &Path) -> Result<PathBuf, InstallerError> {
    let install_dir = data_dir.join("engines").join("stockfish");

    if install_dir.exists() {
        fs::remove_dir_all(&install_dir)?;
    }

    fs::create_dir_all(&install_dir)?;

    download_latest_stockfish(data_dir).await
}

pub fn validate_stockfish_path(path: &Path) -> Result<(), InstallerError> {
    if !path.exists() {
        return Err(InstallerError::Message(format!(
            "The selected file does not exist: {}",
            path.display()
        )));
    }

    if !path.is_file() {
        return Err(InstallerError::Message(format!(
            "The selected path is not a file: {}",
            path.display()
        )));
    }

    if !is_probably_stockfish(path) {
        return Err(InstallerError::Message(
            "The selected file does not look like a Stockfish executable.".to_string(),
        ));
    }

    Ok(())
}

pub fn find_stockfish_executable(root: &Path) -> Option<PathBuf> {
    let mut candidates = Vec::new();
    collect_stockfish_candidates(root, &mut candidates);

    candidates.sort_by_key(|path| std::cmp::Reverse(score_stockfish_candidate(path)));

    candidates.into_iter().next()
}

fn collect_stockfish_candidates(root: &Path, candidates: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(root) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();

        if path.is_dir() {
            collect_stockfish_candidates(&path, candidates);
        } else if is_probably_stockfish(&path) {
            candidates.push(path);
        }
    }
}

fn score_stockfish_candidate(path: &Path) -> i32 {
    let name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    let mut score = 0;

    if name.contains("stockfish") {
        score += 50;
    }

    #[cfg(target_os = "windows")]
    if name.ends_with(".exe") {
        score += 50;
    }

    if name.contains("windows") || name.contains("win") {
        score += 10;
    }

    if name.contains("x86-64") || name.contains("x86_64") {
        score += 8;
    }

    if name.contains("avx2") {
        score += 5;
    }

    if name.contains("faq")
        || name.contains("readme")
        || name.contains("license")
        || name.contains("copying")
    {
        score -= 1000;
    }

    score
}

pub fn is_probably_stockfish(path: &Path) -> bool {
    if !path.exists() || !path.is_file() {
        return false;
    }

    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    if !file_name.contains("stockfish") {
        return false;
    }

    if file_name.contains("faq")
        || file_name.contains("readme")
        || file_name.contains("license")
        || file_name.contains("copying")
    {
        return false;
    }

    let rejected_extensions = [
        "md", "markdown", "txt", "pdf", "html", "htm", "json", "toml", "yaml", "yml", "ini", "cfg",
        "conf", "cpp", "c", "h", "hpp", "nnue", "zip", "tar", "gz", "tgz", "7z",
    ];

    if let Some(ext) = path.extension().and_then(|ext| ext.to_str()) {
        let ext = ext.to_ascii_lowercase();

        if rejected_extensions.contains(&ext.as_str()) {
            return false;
        }

        #[cfg(target_os = "windows")]
        {
            return ext == "exe";
        }
    }

    #[cfg(target_os = "windows")]
    {
        false
    }

    #[cfg(not(target_os = "windows"))]
    {
        true
    }
}

fn unique_install_dir(root: &Path, tag: &str) -> Result<PathBuf, InstallerError> {
    use std::time::{SystemTime, UNIX_EPOCH};

    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|err| InstallerError::Message(format!("System clock error: {err}")))?
        .as_millis();

    Ok(root.join(format!("{}-{millis}", sanitize_file_name(tag))))
}

pub async fn download_latest_stockfish(data_dir: &Path) -> Result<PathBuf, InstallerError> {
    let engines_dir = data_dir.join("engines").join("stockfish");
    ensure_dir(&engines_dir)?;

    let client = reqwest::Client::builder()
        .default_headers(default_headers())
        .build()?;

    let release: GithubRelease = client
        .get("https://api.github.com/repos/official-stockfish/Stockfish/releases/latest")
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;

    let asset = select_asset(&release.assets).ok_or(InstallerError::NoCompatibleAsset)?;
    tracing::info!(asset = %asset.name, tag = %release.tag_name, "downloading Stockfish");

    let bytes = client
        .get(&asset.browser_download_url)
        .send()
        .await?
        .error_for_status()?
        .bytes()
        .await?;

    let target_dir = unique_install_dir(&engines_dir, &release.tag_name)?;
    fs::create_dir_all(&target_dir)?;

    let executable = match if asset.name.ends_with(".zip") {
        extract_zip(&bytes, &target_dir)
    } else if asset.name.ends_with(".tar.gz") || asset.name.ends_with(".tgz") {
        extract_tar_gz(&bytes, &target_dir)
    } else if asset.name.ends_with(".tar") {
        extract_tar(&bytes, &target_dir)
    } else {
        Err(InstallerError::NoCompatibleAsset)
    } {
        Ok(path) => path,
        Err(err) => {
            let _ = fs::remove_dir_all(&target_dir);
            return Err(err);
        }
    };

    mark_executable(&executable)?;
    Ok(executable)
}

pub fn detect_stockfish(configured_path: Option<&str>, data_dir: &Path) -> Option<PathBuf> {
    if let Some(path) = configured_path {
        let path = PathBuf::from(path);
        if is_probably_stockfish(&path) {
            return Some(path);
        }
    }

    if let Ok(path) = which::which("stockfish") {
        if is_probably_stockfish(&path) {
            return Some(path);
        }
    }

    let candidates = candidate_paths(data_dir);
    candidates
        .into_iter()
        .find(|path| is_probably_stockfish(path))
}

fn executable_name_matches(path: &Path) -> bool {
    executable_candidate_score(path).is_some()
}

fn executable_candidate_score(path: &Path) -> Option<i32> {
    let file_name = path.file_name()?.to_str()?.to_ascii_lowercase();

    if !file_name.contains("stockfish") {
        return None;
    }

    // Official archives can contain documentation/source files such as
    // `stockfish.md`. Those passed the old loose "contains stockfish" check
    // and could be selected instead of the engine binary.
    let extension = path
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| ext.to_ascii_lowercase());

    let disallowed_extensions = [
        "md", "markdown", "txt", "rtf", "pdf", "html", "htm", "json", "toml", "yaml", "yml", "ini",
        "cfg", "conf", "sha", "sha256", "sig", "asc", "zip", "tar", "gz", "tgz", "7z", "rar", "c",
        "cc", "cpp", "cxx", "h", "hh", "hpp", "rs", "py", "lua", "sh", "bat", "cmd", "ps1", "nnue",
    ];

    if extension
        .as_deref()
        .is_some_and(|ext| disallowed_extensions.contains(&ext))
    {
        return None;
    }

    #[cfg(target_os = "windows")]
    {
        if extension.as_deref() != Some("exe") {
            return None;
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        // Stockfish release binaries for macOS/Linux normally have no extension.
        // Be conservative and reject unknown extensioned files to avoid selecting
        // docs, scripts, source files, nets, or metadata.
        if extension.is_some() {
            return None;
        }
    }

    let mut score = asset_score(&file_name) + 100;
    if file_name == "stockfish" || file_name == "stockfish.exe" {
        score += 20;
    }
    if file_name.starts_with("stockfish") {
        score += 10;
    }

    Some(score)
}

fn candidate_paths(data_dir: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();

    #[cfg(target_os = "windows")]
    {
        paths.push(PathBuf::from(r"C:\Program Files\Stockfish\stockfish.exe"));
        paths.push(PathBuf::from(
            r"C:\Program Files (x86)\Stockfish\stockfish.exe",
        ));
    }

    #[cfg(target_os = "macos")]
    {
        paths.push(PathBuf::from("/opt/homebrew/bin/stockfish"));
        paths.push(PathBuf::from("/usr/local/bin/stockfish"));
    }

    #[cfg(target_os = "linux")]
    {
        paths.push(PathBuf::from("/usr/bin/stockfish"));
        paths.push(PathBuf::from("/usr/local/bin/stockfish"));
    }

    let downloaded = data_dir.join("engines").join("stockfish");
    if let Ok(entries) = walk_files(&downloaded) {
        paths.extend(
            entries
                .into_iter()
                .filter(|path| executable_name_matches(path)),
        );
    }

    paths
}

fn walk_files(root: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut out = Vec::new();
    if !root.exists() {
        return Ok(out);
    }
    let mut stack = vec![root.to_path_buf()];
    while let Some(path) = stack.pop() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else {
                out.push(path);
            }
        }
    }
    Ok(out)
}

fn select_asset(assets: &[GithubAsset]) -> Option<GithubAsset> {
    let os_terms: &[&str] = if cfg!(target_os = "windows") {
        &["windows", "win"]
    } else if cfg!(target_os = "macos") {
        &["macos", "apple", "darwin"]
    } else if cfg!(target_os = "linux") {
        &["ubuntu", "linux"]
    } else {
        &[]
    };

    let arch_terms: &[&str] = if cfg!(target_arch = "x86_64") {
        &["x86-64", "x86_64", "amd64"]
    } else if cfg!(target_arch = "aarch64") {
        &["armv8", "aarch64", "apple-silicon", "m1"]
    } else {
        &[]
    };

    let mut scored = assets
        .iter()
        .filter(|asset| {
            let name = asset.name.to_ascii_lowercase();
            (name.ends_with(".zip")
                || name.ends_with(".tar")
                || name.ends_with(".tar.gz")
                || name.ends_with(".tgz"))
                && os_terms.iter().any(|term| name.contains(term))
                && arch_terms.iter().any(|term| name.contains(term))
        })
        .map(|asset| (asset_score(&asset.name), asset.clone()))
        .collect::<Vec<_>>();

    scored.sort_by(|a, b| b.0.cmp(&a.0));
    scored.into_iter().map(|(_, asset)| asset).next()
}

fn asset_score(name: &str) -> i32 {
    let name = name.to_ascii_lowercase();
    let mut score = 0;

    for (needle, value) in [
        // Safer defaults first
        ("avx2", 100),
        ("popcnt", 90),
        ("modern", 80),
        ("x86-64", 70),
        // Powerful but less universally safe
        ("bmi2", 60),
        ("avx512", 10),
        ("vnni", 5),
    ] {
        if name.contains(needle) {
            score += value;
        }
    }

    score
}

fn extract_zip(bytes: &[u8], target_dir: &Path) -> Result<PathBuf, InstallerError> {
    let reader = Cursor::new(bytes);
    let mut archive = zip::ZipArchive::new(reader)?;
    let mut executable: Option<(i32, PathBuf)> = None;

    for index in 0..archive.len() {
        let mut file = archive.by_index(index)?;
        if !file.is_file() {
            continue;
        }

        let Some(file_name) = Path::new(file.name())
            .file_name()
            .and_then(|name| name.to_str())
        else {
            continue;
        };

        let output_path = target_dir.join(file_name);
        let mut output = fs::File::create(&output_path)?;
        std::io::copy(&mut file, &mut output)?;

        if let Some(score) = executable_candidate_score(&output_path) {
            if executable
                .as_ref()
                .is_none_or(|(current_score, _)| score > *current_score)
            {
                executable = Some((score, output_path));
            }
        }
    }

    executable
        .map(|(_, path)| path)
        .ok_or(InstallerError::MissingExecutable)
}

fn extract_tar(bytes: &[u8], target_dir: &Path) -> Result<PathBuf, InstallerError> {
    let reader = Cursor::new(bytes);
    extract_tar_reader(reader, target_dir)
}

fn extract_tar_gz(bytes: &[u8], target_dir: &Path) -> Result<PathBuf, InstallerError> {
    let decoder = flate2::read::GzDecoder::new(Cursor::new(bytes));
    extract_tar_reader(decoder, target_dir)
}

fn extract_tar_reader<R: Read>(reader: R, target_dir: &Path) -> Result<PathBuf, InstallerError> {
    let mut archive = tar::Archive::new(reader);
    let mut executable: Option<(i32, PathBuf)> = None;

    for entry in archive.entries()? {
        let mut entry = entry?;
        let path = entry.path()?.to_path_buf();
        let Some(file_name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };

        let output_path = target_dir.join(file_name);
        entry.unpack(&output_path)?;

        if let Some(score) = executable_candidate_score(&output_path) {
            if executable
                .as_ref()
                .is_none_or(|(current_score, _)| score > *current_score)
            {
                executable = Some((score, output_path));
            }
        }
    }

    executable
        .map(|(_, path)| path)
        .ok_or(InstallerError::MissingExecutable)
}

fn default_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(USER_AGENT, HeaderValue::from_static("roblox-chess-script"));
    headers.insert(
        ACCEPT,
        HeaderValue::from_static("application/vnd.github+json"),
    );
    headers
}

fn sanitize_file_name(input: &str) -> String {
    input
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' || ch == '.' {
                ch
            } else {
                '_'
            }
        })
        .collect()
}

#[cfg(unix)]
fn mark_executable(path: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let mut permissions = fs::metadata(path)?.permissions();
    permissions.set_mode(permissions.mode() | 0o755);
    fs::set_permissions(path, permissions)
}

#[cfg(not(unix))]
fn mark_executable(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn executable_candidate_rejects_stockfish_documentation() {
        assert!(!executable_name_matches(Path::new("stockfish.md")));
        assert!(!executable_name_matches(Path::new("docs/stockfish.txt")));
        assert!(!executable_name_matches(Path::new("src/stockfish.cpp")));
    }

    #[test]
    fn executable_candidate_accepts_current_platform_binary_name() {
        assert!(executable_name_matches(Path::new(platform_binary_name())));
    }

    #[test]
    fn extract_zip_prefers_binary_over_stockfish_markdown() {
        use std::io::Write;
        use zip::write::SimpleFileOptions;

        let cursor = Cursor::new(Vec::new());
        let mut writer = zip::ZipWriter::new(cursor);
        let options = SimpleFileOptions::default();

        writer.start_file(platform_binary_name(), options).unwrap();
        writer.write_all(b"fake stockfish binary").unwrap();

        // This used to be able to win because the old check only looked for
        // "stockfish" in the filename.
        writer.start_file("stockfish.md", options).unwrap();
        writer
            .write_all(b"documentation, not an executable")
            .unwrap();

        let bytes = writer.finish().unwrap().into_inner();
        let temp_dir = tempfile::tempdir().unwrap();
        let selected = extract_zip(&bytes, temp_dir.path()).unwrap();

        assert_eq!(
            selected.file_name().and_then(|name| name.to_str()),
            Some(platform_binary_name())
        );
    }

    #[cfg(target_os = "windows")]
    fn platform_binary_name() -> &'static str {
        "stockfish-windows-x86-64-avx2.exe"
    }

    #[cfg(target_os = "macos")]
    fn platform_binary_name() -> &'static str {
        "stockfish-macos-m1-apple-silicon"
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    fn platform_binary_name() -> &'static str {
        "stockfish-ubuntu-x86-64-avx2"
    }
}
