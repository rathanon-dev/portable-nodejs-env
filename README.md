# Portable Node.js Dev Environment ( windows 10/11 )



[![Portable](https://img.shields.io/badge/Status-Portable-green)]()

โปรเจกต์สำหรับสร้าง Development Environment แบบพกพา ช่วยให้คุณรันและพัฒนาโปรเจกต์ Node.js/JavaScript ได้ทันทีบน Windows โดยไม่ต้องติดตั้ง Git, Node.js หรือ 7-Zip ลงในระบบปฏิบัติการ เหมาะสำหรับใส่ Flash Drive หรือย้ายเครื่องทำงานได้อย่างอิสระ

## ✨ คุณสมบัติเด่น
-  Zero Installation & Isolation : เครื่องมือทั้งหมดถูกจำกัดวงไว้ในโฟลเดอร์โปรเจกต์ ไม่ปนเปื้อนกับระบบหลัก (Global Environment)
-  Smart Dynamic Fetching : 
    1. ค้นหาและดาวน์โหลด 7-Zip เวอร์ชันล่าสุดผ่าน NuGet v3 API โดยอัตโนมัติ
    2. ตรวจสอบและดึงข้อมูล Portable Git เวอร์ชันล่าสุดจาก GitHub Releases
    3. ตรวจสอบและดาวน์โหลด Node.js เวอร์ชัน LTS ล่าสุดจากเว็บทางการ
-  Smart Directory Router :  ระบบเมนูอัจฉริยะ ค้นหาและเลือกโปรเจกต์ใน Workspace มาเปิดรันให้อัตโนมัติในกรณีที่มีหลายโปรเจกต์
-  Graceful Exit Handling :  ใช้ Try/Files ในการรันเซิร์ฟเวอร์จำลอง มั่นใจได้ว่าเมื่อกด Ctrl + C เพื่อหยุดรัน สคริปต์จะพาคุณกลับมาที่ Root Directory อย่างปลอดภัยเสมอ

## 🚀 วิธีการใช้งาน (Usage)

### 1. ดูคำอธิบายคำสั่งทั้งหมด (Help Mode)
```powershell
.\setup.ps1 -h
```
### 2. ติดตั้งและเตรียมเครื่องมือ (Installation Mode)
คุณสามารถสั่งติดตั้งเครื่องมือทั้งหมดในครั้งแรก หรือเลือกติดตั้งเฉพาะตัวที่ต้องการได้:
```powershell
.\setup.ps1 -i all    # (ติดตั้งเครื่องมือทั้งหมด 7-Zip, Git, Node.js)
```
```powershell
.\setup.ps1 -i node   # (ติดตั้งเฉพาะ Node.js เท่านั้น)
```
```powershell
.\setup.ps1 -i git   #  (ติดตั้งเฉพาะ Git เท่านั้น)
```
### 3. ตรวจสอบสถานะและเวอร์ชัน (Dev Environment Mode)
ตรวจสอบตำแหน่ง Path และเช็คเวอร์ชันของเครื่องมือใน Environment ณ ปัจจุบัน:
 ```powershell
.\setup.ps1 -env
```
### 4. การรันโปรเจกต์ใน Workspace (Execution Mode)

- โหมดอัตโนมัติ (Smart Default) : วางโฟลเดอร์โปรเจกต์ของคุณไว้ในโฟลเดอร์ workspace จากนั้นพิมพ์คำสั่งด้านล่าง ระบบจะทำการเลือกและรัน npm install และ npm run dev ให้ทันที
```powershell
.\setup.ps1
```
- โหมดดึงจาก URL (Git Clone Mode) :  สั่งโคลนโปรเจกต์จาก GitHub มารันใน Workspace โดยตรงผ่านคำสั่ง:
```powershell
.\setup.ps1 -url "https://github.com/username/your-repo.git"
```
---

## โครงสร้างเครื่องมือภายในระบบ (Toolchain)

สคริปต์นี้จะจัดเตรียมและดาวน์โหลดเครื่องมือแบบ Portable มาวางไว้ที่โฟลเดอร์ tools/ ให้อัตโนมัติ:
- Node.js (LTS Version): ดึงไฟล์โดยตรงจาก Node.js Official Distribution (ลิงก์: https://nodejs.org/dist/)
- Git for Windows (Portable 64-bit): เช็คเวอร์ชันและดาวน์โหลดผ่าน GitHub Releases API ของทีมพัฒนา Git for Windows (ลิงก์: https://github.com/git-for-windows/git/releases)
- 7-Zip CommandLine (7za.exe): ค้นหาและดึงไฟล์เวอร์ชันล่าสุดผ่าน NuGet v3 Service Index (ลิงก์เว็บหลัก: https://www.nuget.org/packages/7-Zip.CommandLine/)

---

## License

MIT License
