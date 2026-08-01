# Portable Node.js Dev Environment ( Windows 10/11 )

[![Portable](https://img.shields.io/badge/Status-Portable-green)]() [![Version](https://img.shields.io/badge/Version-1.2.0-blue)]()

โปรเจกต์สำหรับสร้าง Development Environment แบบพกพา ช่วยให้คุณรันและพัฒนาโปรเจกต์ Node.js/JavaScript ได้ทันทีบน Windows โดยไม่ต้องติดตั้ง Git, Node.js หรือ 7-Zip ลงในระบบปฏิบัติการ เหมาะสำหรับใส่ Flash Drive หรือย้ายเครื่องทำงานได้อย่างอิสระ

## ✨ คุณสมบัติเด่น (V1.2.0 Update)
- 🔒 **Zero Installation & Isolation** : เครื่องมือทั้งหมดถูกจำกัดวงไว้ในโฟลเดอร์โปรเจกต์ ไม่ปนเปื้อนกับระบบหลัก (Global Environment)
- 🚀 **Smart Dynamic Fetching** : 
    1. ค้นหาและดาวน์โหลด 7-Zip เวอร์ชันล่าสุดผ่าน NuGet v3 API โดยอัตโนมัติ
    2. ตรวจสอบและดึงข้อมูล Portable Git เวอร์ชันล่าสุดจาก GitHub Releases
    3. ตรวจสอบและดาวน์โหลด Node.js เวอร์ชัน LTS ล่าสุดจากเว็บทางการ
- 🌐 **Smart Proxy Detection** : รองรับการดึงไฟล์ผ่าน Local CDN Gateway ในวง LAN (ร่นเวลาดาวน์โหลดจากอินเทอร์เน็ต)
- 🧠 **Smart Directory Router** : ระบบเมนูอัจฉริยะ ค้นหาและเลือกโปรเจกต์ใน Workspace มาเปิดรันให้อัตโนมัติในกรณีที่มีหลายโปรเจกต์
- 🧹 **Anti-Zombie Process (Clean Exit)** : ใช้ระบบดักจับการออกจากโปรแกรม (Try/Finally) มั่นใจได้ว่าเมื่อกด Ctrl + C สคริปต์จะระเบิดโปรเซส Node.js เบื้องหลังทิ้งทั้งหมด (ล้างบาง Zombie Process) อย่างปลอดภัย
- ⚡ **Auto-Start Launcher (`start.bat`)** : เพียงดับเบิลคลิก `start.bat` ระบบจะรันโหมด Auto-Detect (`-r`) เข้าสู่โปรเจกต์ล่าสุดให้ทันที

---

## 🚀 วิธีการใช้งาน (Usage)

### 1. ดูคำอธิบายคำสั่งทั้งหมด (Help Mode)
```powershell
.\setup.ps1 -h
```

### 2. ติดตั้งและเตรียมเครื่องมือ (Installation Mode)
คุณสามารถสั่งติดตั้งเครื่องมือทั้งหมดในครั้งแรก หรือเลือกติดตั้งเฉพาะตัวที่ต้องการได้:
  ```powershell
  .\setup.ps1 -i all    # (ติดตั้งเครื่องมือทุกอย่าง 7-Zip, Git, Node.js)
  .\setup.ps1 -i node   # (ติดตั้งเฉพาะ Node.js เท่านั้น)
  .\setup.ps1 -i git    # (ติดตั้งเฉพาะ Git เท่านั้น)
  .\setup.ps1 -i node -p http://192.168.1.2:8080 # (ติดตั้งโดยระบุ Local Proxy)
  ```

### 3. ตรวจสอบสถานะและเวอร์ชัน (Dev Environment Mode)
เปิด Shell สภาพแวดล้อมจำลอง (ขยับเข้าสู่โฟลเดอร์ Workspace อัตโนมัติ):
```powershell
.\setup.ps1 -e
```

### 4. การรันโปรเจกต์ใน Workspace (Execution Mode)
- **โหมดอัตโนมัติ (Smart Default)** : วางโฟลเดอร์โปรเจกต์ของคุณไว้ในโฟลเดอร์ `workspace` จากนั้นพิมพ์คำสั่งด้านล่าง ระบบจะทำการเลือกและรัน `npm install` และ `npm run dev` ให้ทันที
```powershell
.\setup.ps1 -r
```

- **โหมดดึงจาก URL แล้วรันทันที (Combo Clone + Run)** : สั่งโคลนโปรเจกต์จาก GitHub มารันใน Workspace โดยตรงแบบไร้รอยต่อ!
```powershell
.\setup.ps1 -u "https://github.com/username/your-repo.git" -r
```

## 📂 โครงสร้างโปรเจกต์ (Project Structure)

เมื่อรันสคริปต์แล้ว ระบบจะจำลองโครงสร้างโฟลเดอร์ดังนี้:

```text
portable-nodejs-env
├── setup.ps1          # สคริปต์หลักสำหรับจัดการสภาพแวดล้อมทั้งหมด
├── start.bat          # ตัวรันโปรเจกต์ด่วน (คลิกปุ๊บเข้าโฟลเดอร์งานทันที)
├── auto-install.bat   # สคริปต์ดาวน์โหลดอัตโนมัติสำหรับติดตั้งครั้งแรก
├── tools/             # (Auto-generated) ที่เก็บเครื่องมือ Node.js, Git, 7-Zip, Aria2
└── workspace/         # (Auto-generated) พื้นที่สำหรับวางโฟลเดอร์โปรเจกต์ของคุณ
```

---

## ⚙️ โครงสร้างเครื่องมือภายในระบบ (Toolchain)

สคริปต์นี้จะจัดเตรียมและดาวน์โหลดเครื่องมือแบบ Portable มาวางไว้ที่โฟลเดอร์ `tools/` ให้อัตโนมัติ:
- **Node.js (LTS Version)**: ดึงไฟล์โดยตรงจาก Node.js Official Distribution (https://nodejs.org/dist/)
- **Git for Windows (Portable 64-bit)**: เช็คเวอร์ชันและดาวน์โหลดผ่าน GitHub Releases API (https://github.com/git-for-windows/git/releases)
- **7-Zip CommandLine (7za.exe)**: ค้นหาและดึงไฟล์เวอร์ชันล่าสุดผ่าน NuGet v3 Service Index (https://www.nuget.org/packages/7-Zip.CommandLine/)
- **Aria2 (Lightweight Download Utility)**: โหลดไฟล์ขนานหลาย Connection เพื่อความเร็วสูงสุด (https://github.com/aria2/aria2/releases)

---

## License

- **ผู้พัฒนา (Developer):** [rathanon-dev](https://github.com/rathanon-dev)
- **ลิขสิทธิ์ (License):** MIT License

