

## Day 05 - Container Runtime Benchmark: runc vs CRI-O vs containerd

## Architecture in One Line

```
kubelet → CRI Runtime (containerd or CRI-O) → runc → Linux Kernel
```

runc is the low-level OCI runtime both call under the hood. CRI-O and containerd are the CRI layer kubelet talks to.

---

## Why the Numbers Differ

| Metric | runc | CRI-O | containerd |
|--------|------|-------|------------|
| Memory | Lowest — exits after start, no daemon | Low — lean daemon, no extras | Higher — shims + snapshotter + plugins stay alive |
| Syscalls | Minimal — direct kernel calls | Low — one daemon hop | Higher — kubelet→containerd→shim→runc adds IPC |
| CPU (idle) | Zero — process is gone | Near-zero | Slight background  |
| Binary size | ~11 MB | ~67 MB | ~46 MB+ |
| Start latency | Baseline | Near-baseline | Slightly higher at p99 due to gRPC hops |




# Benchmark -1 Runtime memory

Runc has no daemon so no memory

<img width="2230" height="602" alt="image" src="https://github.com/user-attachments/assets/ec143bce-9e54-4616-a307-5b706d5323df" />

# Benchmark -2 System Call Analysis

runc calls the kernel directly with no middleware hops. containerd stacks the most — kubelet → containerd → shim → runc means more IPC, more seccomp surface.

  CRIO System calls
<img width="1780" height="1370" alt="image" src="https://github.com/user-attachments/assets/df473f68-8056-44f6-b385-d4027858d6ab" />

  Containerd System calls

  <img width="1796" height="1390" alt="image" src="https://github.com/user-attachments/assets/bdf6ac2f-7e84-4cc2-98fc-d15464cb6be8" />

  Runc system calls

  <img width="2082" height="1378" alt="image" src="https://github.com/user-attachments/assets/b7e0ff8c-710d-4196-9b68-3a8add950c1b" />
  
# Benchmark -3 CPU Usage

runc drops to zero after start, nothing running. containerd holds slight background CPU from GC cycles and plugin goroutines even at idle.

   <img width="2472" height="1188" alt="image" src="https://github.com/user-attachments/assets/ff51f365-41c6-467d-b24a-febf281c1e5c" />

# Benchmark -4 Startup latency

runc is the baseline — pure kernel namespace and cgroup setup, nothing in between .where as containerd has slightly higher.

  CRIO

  <img width="1860" height="254" alt="image" src="https://github.com/user-attachments/assets/da472a59-5bdb-4d30-87da-450948e16cdf" />
    
  Containerd
    
  <img width="2918" height="356" alt="image" src="https://github.com/user-attachments/assets/2932d68e-3dfc-49cd-8704-3e75c113355c" />

  runc
  
  <img width="1796" height="280" alt="image" src="https://github.com/user-attachments/assets/f37c3db1-fc16-4b3e-bc6b-9ffafe625d39" />
    
# Benchmark  -5 binarysize

  <img width="1974" height="336" alt="image" src="https://github.com/user-attachments/assets/f594eee7-b821-460b-909d-de211295b07e" />



---

**runc** — you're writing a custom container platform, CI runner, or sandboxed execution engine from scratch. You need raw OCI execution with zero daemon overhead. Not for Kubernetes — kubelet speaks CRI, runc doesn't.

**CRI-O** — you control your own infra (bare metal, OpenShift, self-managed K8s) and security posture matters. Smallest syscall surface, no extra tooling bloat, built for exactly one job: run containers for Kubernetes. Choose this when you're doing CIS hardening, Kata Containers, or running on resource-constrained nodes.

**containerd** — you're on EKS, GKE, or AKS, or your team runs standard CNCF tooling (Karpenter, Argo CD, nerdctl). It's the default on every managed cloud for a reason — mature, battle-tested, broad ecosystem fit. If you don't have a specific reason to pick CRI-O, this is your runtime.

---

## One-Line Decision Rule

> Managed cloud → containerd. Self-managed / OpenShift → CRI-O. Raw OCI tooling → runc.




