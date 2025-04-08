targets=(
    "x86_64-pc-windows-gnu"
    "aarch64-apple-darwin"
)

for target in "${targets[@]}"; do
    cargo build --release --target $target
done