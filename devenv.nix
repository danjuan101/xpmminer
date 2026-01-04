{ pkgs, ... }: {

  # 1. Install necessary packages
  packages = [
    pkgs.cmake
    pkgs.ceedling
    pkgs.ncurses
    pkgs.curl
    pkgs.jansson
    pkgs.openssl
    pkgs.gmp
    pkgs.gnumake
    pkgs.gcc      # Manually include GCC
    
    # GPU Dependencies
    pkgs.cudaPackages.cudatoolkit
    pkgs.rocmPackages.hipcc # ROCm/HIP compiler
    pkgs.rocmPackages.clr   # ROCm Common Language Runtime
  ];

  # 2. Environment Variables Configuration
  env = {
    # Ensure CMake uses GCC/G++ from Nix, not the system
    CC = "gcc";
    CXX = "g++";

    # --- CUDA Driver Stub (Crucial for Building) ---
    # We use the 'stub' library for linking during the build process.
    # This allows building on machines without GPUs or with different driver versions.
    # At runtime, we will swap this out for the real system driver using LD_PRELOAD.
    CUDA_STUB_LIB = "${pkgs.cudaPackages.cudatoolkit}/lib/stubs/libcuda.so";
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

    # --- ROCm/HIP Configuration ---
    # Fixes "HIP not found" errors by explicitly pointing to the installation root
    HIP_ROOT_DIR = "${pkgs.rocmPackages.hipcc}";
    ROCM_PATH = "${pkgs.rocmPackages.hipcc}";
  };

  # 3. Build Scripts
  # Usage: run 'build-miner' inside the shell
  scripts.build-miner.exec = ''
    echo "⚙️  Auto-configuring project (CUDA + HIP)..."
    cmake -S src -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILDCUDAMINER=ON \
      -DBUILDHIPMINER=ON \
      -DBUILDOPENCLMINER=OFF \
      -DCUDA_DRIVER_LIBRARY=$CUDA_STUB_LIB \
      -DHIP_ROOT_DIR=$HIP_ROOT_DIR
    echo "🔨 Starting multi-core build..."
    cmake --build build -j$(nproc)
  '';

  # 4. Smart Shell Entry Hook
  # This script automatically detects your OS (Ubuntu/WSL) drivers and injects them.
  enterShell = ''
    echo "=========================================="
    echo "🚀 xpmminer Development Environment"
    echo "=========================================="

    # --- Auto-Detect System NVIDIA Drivers ---
    # Define common paths where Linux/WSL stores GPU drivers
    DRIVER_SEARCH_PATHS=(
        "/usr/lib/x86_64-linux-gnu"  # Ubuntu Native / Debian
        "/usr/lib/wsl/lib"           # Windows Subsystem for Linux (WSL2)
        "/usr/lib64"                 # Fedora / RHEL / CentOS
    )

    FOUND_LIBCUDA=""
    FOUND_JIT=""

    # Step A: Search for the main Driver (libcuda.so)
    for path in "''${DRIVER_SEARCH_PATHS[@]}"; do
        if [ -d "$path" ]; then
            # Find libcuda.so.1 or similar
            res=$(find "$path" -maxdepth 1 -name "libcuda.so.*" -print -quit)
            if [ -n "$res" ]; then
                FOUND_LIBCUDA="$res"
                echo "✅ Found System Driver: $res"
                
                # Step B: If Driver found, look for JIT Compiler in the same folder
                # (Required for RTX 30 series and newer to compile PTX)
                jit_res=$(find "$path" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit)
                if [ -n "$jit_res" ]; then
                    FOUND_JIT="$jit_res"
                    echo "✅ Found JIT Compiler : $jit_res"
                fi
                break
            fi
        fi
    done

    # Step C: Inject drivers using LD_PRELOAD
    # This forces the application to use the system driver instead of the Nix stub
    if [ -n "$FOUND_LIBCUDA" ]; then
        if [ -n "$FOUND_JIT" ]; then
            # Load both Driver and JIT Compiler (Native Linux Mode)
            export LD_PRELOAD="$FOUND_LIBCUDA $FOUND_JIT"
        else
            # Load Driver only (Legacy / WSL Mode)
            export LD_PRELOAD="$FOUND_LIBCUDA"
        fi
        echo "💉 Auto-injected system drivers via LD_PRELOAD"
    else
        echo "⚠️  Warning: Could not find system NVIDIA drivers automatically."
        echo "    If you want to run the miner, you might need to set LD_PRELOAD manually."
    fi

    # Ensure Nix provided binaries (nvcc, hipcc) are in PATH
    export PATH="$CUDA_PATH/bin:$ROCM_PATH/bin:$PATH"
    
    echo ""
    echo "💡 Usage:"
    echo " Run 'build-miner'  -> Auto-start compilation"
    echo " Run './build/Cuda/xpmcuda ...' -> Start Mining"
  '';
  
  git-hooks.excludes = [ ".devenv" ];
}
