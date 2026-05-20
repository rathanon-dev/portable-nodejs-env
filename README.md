# portable-dev-env for windows 11 / 10

[![Portable](https://img.shields.io/badge/Status-Portable-green)]()

โปรเจกต์นี้คือ "Portable Development Environment" ที่ช่วยให้คุณสามารถรันโปรเจกต์ Node.js ได้ทุกที่โดยไม่ต้องติดตั้ง Git, Node.js หรือ 7-Zip ลงในเครื่อง (Windows)

## ✨ คุณสมบัติเด่น
- **Zero Installation**: ไม่ต้องติดตั้งซอฟต์แวร์ลงระบบ
- **Smart Logic**: ตรวจสอบและดาวน์โหลดเครื่องมือที่จำเป็นให้โดยอัตโนมัติ
- **Workspace-Ready**: รองรับการโคลนโปรเจกต์ผ่าน URL หรือรันโปรเจกต์ในเครื่อง

## 🚀 วิธีการใช้งาน

### 1. ติดตั้งเครื่องมือ (เฉพาะครั้งแรก)
รันคำสั่งด้านล่างเพื่อเตรียมความพร้อม:
```powershell
.\setup.ps1 -i all
```
### 2. รันโปรเจกต์
คุณสามารถรันโปรเจกต์ของคุณได้โดย:

- โหมดอัตโนมัติ: วางโปรเจกต์ไว้ในโฟลเดอร์ workspace แล้วพิมพ์ .\setup.ps1

- โหมด URL: พิมพ์  `` .\setup.ps1 -url "https://github.com/your-repo" ``

### 🛠️ เครื่องมือที่ใช้ใน Environment นี้
โปรเจกต์นี้จะจัดการ Environment ให้คุณอัตโนมัติ:
* Git
* Node.js
* 7-Zip (สำหรับจัดการไฟล์)

### 📜 License
MIT License

 
