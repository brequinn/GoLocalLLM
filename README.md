# GoLocalLLM
Run Large Language Models and Vision Models locally on iOS with MLX

<p align="center">
 <img width="837" height="375" alt="GoLocalLLM" src="https://github.com/user-attachments/assets/a00f4439-3366-43b4-8afb-d1d7b71ff066" />
</p>

**Run powerful AI models entirely offline on your iPhone.**  
Built with [Apple MLX](https://github.com/ml-explore/mlx). No cloud, no servers, no data collection.

---

## Features
- 📱 Download and run LLMs or VLMs directly on your iPhone  
- 🔒 Fully offline, data never leaves your device  
- ⚡ Optimized for Apple Silicon and MLX framework  
- 🛠 Open source and extensible  
- 🌙 Works in Airplane Mode  

---

## How It Works
1. On first launch the app auto-downloads the tiny **Qwen 3:0.6b** model so you can start chatting immediately.  
2. Select and download any additional models (LLM or VLM).  
3. Run inference locally using MLX.  
4. Interact through a clean SwiftUI interface.  

> Tip: After the initial Qwen 3 download completes (it’s only ~0.6B parameters), the UI switches from “Loading Qwen 3” to ready, and future startups reuse the cached weights instantly.

---

## Installation
Clone the repository and open the project in Xcode:

```bash
git clone https://github.com/yourusername/GoLocalLLM.git
cd GoLocalLLM
open GoLocalLLM.xcodeproj
```

## License
MIT License. See `LICENSE`.
