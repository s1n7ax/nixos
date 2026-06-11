# Never Run Nix Garbage Collection Inside dev-vm

Running `nix-collect-garbage` (or the `nixos-clean` alias) inside the dev-vm
microVM permanently breaks it. GC must only run on the host.

## Symptom

- SSH to the VM times out (`ssh -p 2222 localhost` hangs during banner
  exchange) even though `microvm@dev-vm.service` is `active (running)`.
- The boot log shows the VM dropping into emergency mode:

```
journalctl -u microvm@dev-vm -b | grep -E 'FAILED|emergency'
[FAILED] Failed to start Find NixOS closure.
[DEPEND] Dependency failed for Initrd Default Target.
[  OK  ] Reached target Emergency Mode.
```

The emergency console is unusable too (`root account is locked`).

## Root Cause

The VM's `/nix/store` is an overlayfs (`system/nixos/utils/microvm.nix`):

- lower layer: the host's `/nix/store`, shared read-only via virtiofs
- upper layer: `/nix/.rw-store`, backed by
  `/var/lib/microvms/dev-vm/nix-store.img`

When GC runs inside the guest, it "deletes" store paths that actually live in
the host store. Overlayfs can't remove files from the read-only lower layer,
so it records **whiteouts** in the upper image instead — permanently hiding
those paths from the guest. GC hides the VM's own system closure, so on the
next boot the initrd can't find `init` and drops into emergency mode before
sshd starts.

## Recovery

Wipe the poisoned overlay image; `autoCreate = true` rebuilds it on start:

```sh
sudo systemctl stop microvm@dev-vm
sudo rm /var/lib/microvms/dev-vm/nix-store.img
sudo systemctl start microvm@dev-vm
```

This is safe: `/home` and the SSH host keys live in separate images. The only
loss is store paths that were built or downloaded inside the VM.

## Prevention

- To reclaim disk space, run GC **on the host**. The VM picks up the shared
  store as-is.
- If the VM's writable store image itself fills up, recreate it with the
  recovery steps above instead of running GC inside the guest.
