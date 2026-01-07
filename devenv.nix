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
    pkgs.gcc

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

  # 4. Helper function to detect CUDA drivers
  # This function is used both in enterShell and in wrapper scripts
  scripts.detect-cuda-drivers.exec = ''
    # Detect if we're running in WSL2
    IS_WSL2=false
    if [ -f "/proc/sys/fs/binfmt_misc/WSLInterop" ] || grep -qi "microsoft" /proc/version 2>/dev/null; then
        IS_WSL2=true
    fi

    FOUND_LIBCUDA=""
    FOUND_JIT=""

    # Priority logic:
    # - In WSL2: Use WSL2 driver first to avoid conflicts
    # - In native Linux: Use Ubuntu native driver first
    if [ "$IS_WSL2" = "true" ]; then
        # WSL2 environment: Prefer WSL2 driver to avoid conflicts
        if [ -d "/usr/lib/wsl/lib" ]; then
            res=$(find "/usr/lib/wsl/lib" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
            if [ -n "$res" ]; then
                FOUND_LIBCUDA="$res"
                jit_res=$(find "/usr/lib/wsl/lib" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null)
                if [ -n "$jit_res" ]; then
                    FOUND_JIT="$jit_res"
                fi
            fi
        fi
        # Fallback to Ubuntu native if WSL2 driver not found
        if [ -z "$FOUND_LIBCUDA" ] && [ -d "/usr/lib/x86_64-linux-gnu" ]; then
            res=$(find "/usr/lib/x86_64-linux-gnu" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
            if [ -n "$res" ]; then
                FOUND_LIBCUDA="$res"
                jit_res=$(find "/usr/lib/x86_64-linux-gnu" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null)
                if [ -n "$jit_res" ]; then
                    FOUND_JIT="$jit_res"
                fi
            fi
        fi
    else
        # Native Linux environment: Prefer Ubuntu native driver
        if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
            res=$(find "/usr/lib/x86_64-linux-gnu" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
            if [ -n "$res" ]; then
                FOUND_LIBCUDA="$res"
                jit_res=$(find "/usr/lib/x86_64-linux-gnu" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null)
                if [ -n "$jit_res" ]; then
                    FOUND_JIT="$jit_res"
                fi
            fi
        fi
        # Fallback to WSL2 driver if Ubuntu native not found (unlikely in native Linux)
        if [ -z "$FOUND_LIBCUDA" ] && [ -d "/usr/lib/wsl/lib" ]; then
            res=$(find "/usr/lib/wsl/lib" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
            if [ -n "$res" ]; then
                FOUND_LIBCUDA="$res"
                jit_res=$(find "/usr/lib/wsl/lib" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null)
                if [ -n "$jit_res" ]; then
                    FOUND_JIT="$jit_res"
                fi
            fi
        fi
    fi

    # Final fallback: Try other paths
    if [ -z "$FOUND_LIBCUDA" ]; then
        for path in "/usr/lib64"; do
            if [ -d "$path" ]; then
                res=$(find "$path" -maxdepth 1 -name "libcuda.so.*" -print -quit 2>/dev/null)
                if [ -n "$res" ]; then
                    FOUND_LIBCUDA="$res"
                    jit_res=$(find "$path" -maxdepth 1 -name "libnvidia-ptxjitcompiler.so.*" -print -quit 2>/dev/null)
                    if [ -n "$jit_res" ]; then
                        FOUND_JIT="$jit_res"
                    fi
                    break
                fi
            fi
        done
    fi

    # Output the result
    if [ -n "$FOUND_LIBCUDA" ]; then
        if [ -n "$FOUND_JIT" ]; then
            echo "$FOUND_LIBCUDA $FOUND_JIT"
        else
            echo "$FOUND_LIBCUDA"
        fi
    fi
  '';

  # 5. Smart Shell Entry Hook
  # This script automatically detects your OS (Ubuntu/WSL) drivers and injects them.
  enterShell = ''
    echo "=========================================="
    echo "🚀 xpmminer Development Environment"
    echo "=========================================="

    # Detect CUDA drivers and set environment variables
    PRELOAD=$(detect-cuda-drivers)
    if [ -n "$PRELOAD" ]; then
        export LD_PRELOAD="$PRELOAD"
        # Extract just the first path for display
        FIRST_DRIVER=$(echo "$PRELOAD" | awk '{print $1}')
        echo "✅ Found System Driver: $FIRST_DRIVER"
        if echo "$PRELOAD" | grep -q "libnvidia-ptxjitcompiler"; then
            JIT_DRIVER=$(echo "$PRELOAD" | awk '{print $2}')
            echo "✅ Found JIT Compiler : $JIT_DRIVER"
        fi
        echo "💉 Auto-injected system drivers via LD_PRELOAD"
    else
        echo "⚠️  Warning: Could not find system NVIDIA drivers automatically."
        echo "    If you want to run the miner, you might need to set LD_PRELOAD manually."
    fi

    # Ensure Nix provided binaries (nvcc, hipcc) are in PATH
    export PATH="$CUDA_PATH/bin:$ROCM_PATH/bin:$PATH"

    # WSL2 specific: Add WSL driver paths to LD_LIBRARY_PATH if they exist
    if [ -d "/usr/lib/wsl/lib" ]; then
        export LD_LIBRARY_PATH="/usr/lib/wsl/lib:''${LD_LIBRARY_PATH:-}"
    fi

    echo ""
    echo "💡 Usage:"
    echo " Run 'build-miner'  -> Auto-start compilation"
    echo " Run 'cd build/Cuda && ./xpmcuda ...' -> Start Mining"
  '';

  git-hooks.excludes = [ ".devenv" ];
}
