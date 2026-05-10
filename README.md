devops-sandbox/
├── platform/          # Lifecycle scripts + API
│   ├── create_env.sh
│   ├── destroy_env.sh
│   ├── cleanup_daemon.sh
│   ├── simulate_outage.sh
│   └── api.py
├── nginx/             # Routing layer
│   ├── nginx.conf
│   ├── Dockerfile
│   └── conf.d/        # Auto-generated per-env configs
├── monitor/           # Health monitoring
│   ├── health_poller.py
│   └── Dockerfile
├── demo-app/          # Sample application
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── logs/              # Runtime logs (gitignored)
├── envs/              # Runtime state (gitignored)
├── Makefile
└── README.md

<img width="1536" height="1024" alt="Devops Stage 5 Arch" src="https://github.com/user-attachments/assets/872cb364-a276-464b-a8d7-ea39463420eb" />
