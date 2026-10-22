<div align="center">

# Waste Classification

**Đưa một vật thể vào khung hình. Ứng dụng trả về nhãn rác, độ tin cậy và cách xử lý.**

[![Bản phát hành mới nhất](https://img.shields.io/github/v/release/VoxNut/Waste_Classification?style=flat-square&color=5FA084)](https://github.com/VoxNut/Waste_Classification/releases/latest)
![Flutter](https://img.shields.io/badge/Flutter-Android-5FA084?style=flat-square&logo=flutter&logoColor=white)
![Số nhãn](https://img.shields.io/badge/model-9_nhãn-F2DDA4?style=flat-square)
[![Giấy phép: GPL v3](https://img.shields.io/github/license/VoxNut/Waste_Classification?style=flat-square&color=5FA084)](LICENSE)

[English](README.md) · **Tiếng Việt**

[Tải APK mới nhất](https://github.com/VoxNut/Waste_Classification/releases/latest)

</div>

Waste Classification là ứng dụng Flutter Android được xây dựng cho IT-Challenge lần II năm 2026. Phần quan trọng không chỉ là chụp được ảnh: ảnh gửi lên model phải đúng với vùng người dùng nhìn thấy. Ứng dụng lấy chính xác phần nằm trong khung quét, gọi API phân loại, sau đó lưu kết quả cục bộ để xem lại và thống kê.

## Demo

https://github.com/user-attachments/assets/4432e38d-ee5b-4b20-be4b-e816d4c3cab6

[Mở video demo độ phân giải đầy đủ](repo%20images/Demo%20Video.mp4)

<table>
  <tr>
    <td align="center"><img src="repo%20images/main%20screen.jpg" width="230" alt="Màn hình chính"><br><sub>Bắt đầu quét</sub></td>
    <td align="center"><img src="repo%20images/take%20picture%20screen.jpg" width="230" alt="Khung camera"><br><sub>Giữ một vật thể trong khung</sub></td>
    <td align="center"><img src="repo%20images/result%20screen.jpg" width="230" alt="Kết quả phân loại"><br><sub>Kết quả và cách xử lý</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="repo%20images/stats.jpg" width="230" alt="Thống kê quét"><br><sub>Thống kê ngày, tuần và tháng</sub></td>
    <td align="center"><img src="repo%20images/scan%20details.jpg" width="230" alt="Chi tiết lần quét"><br><sub>Chi tiết lần quét đã lưu</sub></td>
    <td align="center"><img src="repo%20images/language.jpg" width="230" alt="Cài đặt ngôn ngữ"><br><sub>Tiếng Việt và tiếng Anh</sub></td>
  </tr>
</table>

## Ứng dụng có gì

- Camera có khung hướng dẫn; chỉ vùng nằm trong khung được gửi đi phân loại.
- Chín nhãn model: `Cardboard`, `Food Organics`, `Glass`, `Metal`, `Miscellaneous Trash`, `Paper`, `Plastic`, `Textile Trash` và `Vegetation`.
- Độ tin cậy, thông tin về nhóm rác và cách xử lý đề xuất.
- Lịch sử cục bộ gồm ảnh, thời gian, nhãn và độ tin cậy.
- Thống kê tỷ lệ rác theo ngày, tuần hoặc tháng.
- Giao diện tiếng Việt và tiếng Anh.

## Luồng phân loại

```text
Camera → crop đúng khung quét → POST /predict → kết quả → lịch sử SQLite
```

Model được triển khai riêng, không đóng gói trực tiếp trong APK. Hợp đồng hiện tại bám theo notebook của dự án:

| Thành phần | Giá trị |
| --- | --- |
| Model | EfficientNet-B0, xuất sang ONNX |
| Đầu vào | RGB `224 × 224`, chuẩn hóa ImageNet |
| Request | `multipart/form-data`, tên field `file` |
| Response | `predicted_class`, `confidence`, `all_probabilities` |
| Triển khai | [Docker Space công khai](https://huggingface.co/spaces/voxnuts947/waste-classification-api) |

Ứng dụng quy đổi chín nhãn model thành ba nhóm dễ theo dõi: rác hữu cơ, rác tái chế và rác khác.

## Chạy dự án

Yêu cầu: Flutter SDK, Android SDK và thiết bị hoặc emulator Android 7.0 trở lên.

```bash
flutter pub get
flutter run
```

Nên dùng endpoint riêng khi phát triển:

```bash
flutter run \
  --dart-define=WASTE_API_BASE_URL=https://your-api.example.com
```

Nếu chỉ cần demo giao diện, không gọi model:

```bash
flutter run --dart-define=CLASSIFIER_MODE=mock
```

Bản phát hành mặc định sử dụng Hugging Face Docker Space công khai của dự án.
Mã API, Dockerfile, bộ kiểm thử và model ONNX chính xác được lưu trong
[`huggingface-space/`](huggingface-space/). Space miễn phí có thể mất một lúc để
khởi động lại sau thời gian không hoạt động, vì vậy ứng dụng chờ cold start rồi
mới thử lại.

## Cấu trúc chính

```text
lib/
├── core/       theme, cấu hình và widget dùng chung
├── data/       model dữ liệu, SQLite và lưu ảnh cục bộ
├── features/   trang chủ, camera, kết quả, lịch sử, cài đặt
└── services/   API/mock classifier và quyền camera

huggingface-space/  FastAPI, Dockerfile, model ONNX và bộ kiểm thử backend
```

Riverpod chọn implementation phân loại. SQLite lưu metadata của các lần quét; ảnh nằm trong thư mục riêng của ứng dụng. `easy_localization` quản lý hai ngôn ngữ và font Be Vietnam Pro được đóng gói sẵn, không tải lúc chạy.

## Kiểm tra

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

Trên Windows, dùng script phát hành đã kiểm chứng để xóa output cũ, chạy toàn bộ kiểm tra, build APK và xác nhận các file dịch cùng font đã được đóng gói:

```powershell
.\tool\build_release.ps1
```

## Dữ liệu và quyền riêng tư

Lịch sử quét được lưu trên thiết bị. Ở chế độ API, một ảnh đã crop được gửi tới endpoint `/predict` để suy luận; ứng dụng không dùng endpoint này làm nơi lưu trữ đám mây. Xóa dữ liệu ứng dụng hoặc gỡ cài đặt có thể làm mất lịch sử cục bộ.

## Tài liệu tham khảo

- [Notebook phân loại rác](https://www.kaggle.com/code/ledainhan/waste-classification)
- [Notebook API phân loại rác](https://www.kaggle.com/code/ledainhan/waste-classification-api)

## Giấy phép

Dự án được phát hành theo [GNU General Public License v3.0](LICENSE).
