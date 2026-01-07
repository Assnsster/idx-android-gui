{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.qemu
    pkgs.htop
    pkgs.cloudflared
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.wget
    pkgs.git
    pkgs.python3
  ];

  idx.workspace.onStart = {
    qemu = ''
      set -e

      # =========================
      # One-time cleanup
      # =========================
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/* || true
        find /home/user -mindepth 1 -maxdepth 1 \
          ! -name 'idx-windows-gui' \
          ! -name '.cleanup_done' \
          ! -name '.*' \
          -exec rm -rf {} + || true
        touch /home/user/.cleanup_done
      fi

      # =========================
      # Paths
      # =========================

      SKIP_QCOW2_DOWNLOAD=0

      VM_DIR="$HOME/qemu"
      RAW_DISK="$VM_DIR/android.qcow2"
      NOVNC_DIR="$HOME/noVNC"
    

      mkdir -p "$VM_DIR"

      if [ "$SKIP_QCOW2_DOWNLOAD" -ne 1 ]; then
  if [ ! -f "$RAW_DISK" ]; then
    echo "Downloading QCOW2 disk..."
    wget -O "$RAW_DISK" "https://api.cloud.hashicorp.com/vagrant-archivist/v1/object/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJhbmRyb2lkOTByMi9hYmRyLzkwL2FuZHJvaWRxY293Mi83YmU3OThmZi1lYjlmLTExZjAtYjcyNS0xZTIyZjkxZDY5OGYiLCJtb2RlIjoiciIsImZpbGVuYW1lIjoiYWJkcl85MF9hbmRyb2lkcWNvdzJfYW1kNjQuYm94In0.SW41tPC7xJ4IRH-8t3_r6LTrJVXWCzKGeSZpB16YTS0"
  else
    echo "QCOW2 disk already exists, skipping download."
  fi
else
  echo "SKIP_QCOW2_DOWNLOAD=1 → QCOW2 logic skipped."
fi

      # =========================
      # Clone noVNC if missing
      # =========================
      if [ ! -d "$NOVNC_DIR/.git" ]; then
        echo "Cloning noVNC..."
        mkdir -p "$NOVNC_DIR"
        git clone https://github.com/novnc/noVNC.git "$NOVNC_DIR"
      else
        echo "noVNC already exists, skipping clone."
      fi

      # =========================
      # Start QEMU (KVM + ANDROID 9.0 R2 + VMWARE VGA + E1000 NETWORK CARF) 28/8
      # =========================
      echo "Starting QEMU..."
      nohup qemu-system-x86_64   -enable-kvm   -cpu host,+topoext,hv_relaxed,hv_spinlocks=0x1fff,hv-passthrough,+pae,+nx,kvm=on,+svm   -smp 8,cores=8  -M q35,usb=on   -device usb-tablet   -m 27.8G   -device virtio-balloon-pci   -vga vmware   -net nic,netdev=n0,model=e1000   -netdev user,id=n0,hostfwd=tcp::5901-:5901   -boot c   -device virtio-serial-pci   -device virtio-rng-pci   -uuid e47ddb84-fb4d-46f9-b531-14bb15156336 -vnc :0 -hda $RAW_DISK > /tmp/qemu.log 2>&1 &


      # =========================
      # Start noVNC on port 8888
      # =========================
      echo "Starting noVNC..."
      nohup "$NOVNC_DIR/utils/novnc_proxy" \
        --vnc 127.0.0.1:5900 \
        --listen 8888 \
        > /tmp/novnc.log 2>&1 &

      # =========================
      # Start Cloudflared tunnel
      # =========================
      echo "Starting Cloudflared tunnel..."
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:8888 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 10

      if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
        URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
        echo "========================================="
        echo " 🌍 Windows 11 QEMU + noVNC ready:"
        echo "     $URL/vnc.html"
        echo "     $URL/vnc.html" > /home/user/idx-windows-gui/noVNC-URL.txt
        echo "========================================="
      else
        echo "❌ Cloudflared tunnel failed"
      fi

      # =========================
      # Keep workspace alive
      # =========================
      elapsed=0
      while true; do
        echo "Time elapsed: $elapsed min"
        ((elapsed++))
        sleep 60
      done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      qemu = {
        manager = "web";
        command = [
          "bash" "-lc"
          "echo 'noVNC running on port 8888'"
        ];
      };
      terminal = {
        manager = "web";
        command = [ "bash" ];
      };
    };
  };
}
