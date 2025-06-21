# Quick Start

```
windsor init local
windsor up --install --verbose
kubectl port-forward --address 0.0.0.0 svc/home-assistant -n home-assistant 8123:8123

Visit: http://localhost:8123
```

# Home Assistant in Kubernetes

https://ohmydevops.l3st-tech.com/posts/deploy-homeassistant-kubernetes/?utm_source=chatgpt.com

## Using Helm Chart
https://github.com/pajikos/home-assistant-helm-chart/blob/main/charts/home-assistant/README.md


# MailU
https://mailu.io/2024.06/

# Hetzner 
https://community.hetzner.com/tutorials/setup-your-own-scalable-kubernetes-cluster

# WireGuard

https://www.wireguard.com/#conceptual-overview
https://www.jeroenbaten.nl/the-complete-guide-to-setting-up-a-multi-peer-wireguard-vpn/
https://docs.netgate.com/pfsense/en/latest/recipes/wireguard-s2s.html
https://github.com/wg-easy/wg-easy
https://community.hetzner.com/tutorials/installing-wireguard-ui-using-docker-compose

## Linux Server
https://github.com/linuxserver/docker-wireguard

Good video
https://www.youtube.com/watch?v=c2vOleGvJ_Y

Google: myipaddress, 104.54.72.210

Open the port in the compose file on the router

Use this to see the ports are available after docker compose up

$ docker container ls 
