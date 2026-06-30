# Day 6 Container Runtime Security Hardening

Runtime security implementation using Docker seccomp profiles, AppArmor, Linux capabilities, read-only filesystems, non-root containers, and Docker Bench Security — validated against CIS Docker Benchmark recommendations.


| Control                  | Description                                                                                      |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| **Non-root User**        | Container runs as a non-root user to minimize the impact of a compromise.                        |
| **AppArmor**             | AppArmor enforces mandatory access controls to restrict container actions on the host.           |
| **Seccomp**              | Seccomp filters system calls and blocks potentially dangerous kernel interactions.               |
| **Capabilities**         | Linux capabilities are reduced to grant only the privileges required by the application.         |
| **No New Privileges**    | Prevents processes from gaining additional privileges through privilege escalation mechanisms.   |
| **Least Privilege**      | Containers are configured with only the permissions and resources necessary for their operation. |
| **Read-only Filesystem** | The container root filesystem is mounted as read-only to prevent unauthorized modifications.     |


## Prerequisites

Verify runtime security support before proceeding.

**AppArmor status:**
```bash
sudo aa-status
```

**Kernel support:**
```bash
cat /sys/module/apparmor/parameters/enabled
# Expected: Y
```

**Docker security options:**
```bash
docker info | grep -A5 "Security Options"
# Expected: apparmor, seccomp, cgroupns
```

# Level 1  Run container as non-root-user

 
  <img width="2386" height="152" alt="image" src="https://github.com/user-attachments/assets/ef0c6676-f6e2-42c9-9111-5e9f4701663d" />

# Level -2  Linux Capabilities

Inspect default capabilities:
```bash
docker exec secure cat /proc/1/status | grep Cap
```
 <img width="2306" height="304" alt="image" src="https://github.com/user-attachments/assets/c7ffae91-6d35-4121-828f-506cc0d0f8f1" />

Drop all, add only what's needed:
```bash
docker run -d \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  secure:v1
```

Verify:

<img width="2930" height="266" alt="image" src="https://github.com/user-attachments/assets/c41b4d6a-6f13-470e-a35b-d6f074d15a09" />

  

   

 # Level -3 seccomp profiles

   ```bash
mkdir seccomp && cd seccomp

curl -L -o default.json \
  https://raw.githubusercontent.com/moby/profiles/main/seccomp/default.json
 
```

Run with seccomp:
```bash
docker run -d \
  --security-opt seccomp=./seccomp/default.json \
  secure:v1
  ```
 check seccomp profile is enabled or not.
```bash
docker exec secure grep Seccomp /proc/self/status
# Seccomp: 2
# Seccomp_filters: 1
```
 <img width="2940" height="216" alt="image" src="https://github.com/user-attachments/assets/c4be7f4c-7769-4f06-bc6f-128f2e29f57b" />


<img width="2922" height="236" alt="image" src="https://github.com/user-attachments/assets/1e923694-fe12-44b3-b6ec-277cc83d13fb" />

 # Level -4 App Armour

  App armour enabled

  <img width="2902" height="276" alt="image" src="https://github.com/user-attachments/assets/538b5f07-e1bc-49e4-91e9-6e9e673c5ee0" />

  Use secrets  on the host, can be accessed by the container

  <img width="2940" height="990" alt="image" src="https://github.com/user-attachments/assets/82fb8483-022c-4807-9f23-6b00bbe951b4" />

  Journelctl logs for app armour to check permisson denied.

  <img width="2918" height="448" alt="image" src="https://github.com/user-attachments/assets/f23e2a0e-5c4d-45b2-b5ff-9002734243f2" />


 # Level -5 Read only
 
  Read-only file system
  
  <img width="2940" height="282" alt="image" src="https://github.com/user-attachments/assets/d0bba235-85f2-43bd-96e5-cd9ec2285fc5" />




Benchmark reports


<img width="2940" height="1082" alt="image" src="https://github.com/user-attachments/assets/1a1bb983-e418-4e04-b186-b3d8040fe656" />



## Key Learnings

- Container runtime hardening with defense in depth
- Mandatory Access Control using AppArmor
- Syscall filtering using seccomp
- Linux capabilities and least-privilege principle
- Read-only root filesystem enforcement
- CIS Docker Benchmark controls and auditing

---

## References

- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [AppArmor Documentation](https://ubuntu.com/server/docs/apparmor)
- [Seccomp Security Profiles](https://docs.docker.com/engine/security/seccomp/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)




  



  






