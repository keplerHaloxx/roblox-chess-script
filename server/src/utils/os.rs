/// Useful for macos as executables have no extension.
/// So instead we allow user to choose any file type they want,
/// then validate the file.
#[cfg(target_os = "macos")]
pub fn is_executable(path: &std::path::Path) -> bool {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    fs::metadata(path)
        .map(|meta| meta.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}
