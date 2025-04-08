# Define an array of targets
$targets = @(
    "x86_64-pc-windows-gnu",
    "aarch64-apple-darwin"
)

# Loop through each target and build
foreach ($target in $targets) {
    Write-Host "Building for target: $target"
    cargo build --release --target $target
}
