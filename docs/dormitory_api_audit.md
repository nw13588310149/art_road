# 宿管端接口与页面映射

更新时间：2026-06-14

Swagger 分组：`v2智慧校园-宿舍端`

基础路径：`/app/school/v2/dormitory`

## 接口清单

| 页面/能力 | 方法 | 路径 | 主要入参 |
| --- | --- | --- | --- |
| 首页通知 | POST | `/noticeList` | `current`, `size`, 可选 `type/status` |
| 通知详情 | POST | `/noticeDetail` | `id` |
| 宿管首页工作台 | POST | `/index` | 无 |
| 管辖宿舍楼 | POST | `/dormitoryManagedBuildingList` | 无 |
| 楼层列表 | POST | `/dormitoryFloorList` | `buildingId` |
| 查寝顶部统计 | POST | `/dormitoryCheckStat` | 无 |
| 按房间查寝 | POST | `/dormitoryCheckRoomList` | 可选 `date/buildingId/floorId` |
| 房间一键打卡 | POST | `/dormitoryCheckRoomOneClick` | `roomId`，可选 `date` |
| 单学生状态修改 | POST | `/dormitoryCheckUserUpdate` | `userId/status`，可选 `date` |
| 查寝历史 | POST | `/dormitoryCheckHistory` | 日期范围、分页，可选楼/层/房间/状态 |
| 查寝详情 | POST | `/dormitoryCheckDetail` | `id` |
| 查寝异常处理 | POST | `/dormitoryCheckExceptionHandle` | `checkId/studentId/handleStatus`，可选 `remark` |
| 查寝 Excel 导出 | GET | `/dormitoryCheckExport` | 日期范围，可选楼/层/房间/状态 |
| 补卡申请列表 | POST | `/dormitoryMakeupList` | 分页，可选 `buildingId/status` |
| 补卡申请详情 | POST | `/dormitoryMakeupDetail` | `id` |
| 补卡审批 | POST | `/dormitoryMakeupAudit` | `id/status`，可选 `auditReason` |

## 当前页面映射

| Flutter 页面 | 已接能力 | 本轮完善 |
| --- | --- | --- |
| `dorm_manager_home_view.dart` | 首页工作台、通知列表、通知详情 | 修正 `totalBedCount`、`unhandledExceptionCount` 映射；并行加载管辖楼；移除伪造值班数据 |
| `dorm_manager_check_by_room_view.dart` | 楼栋/楼层筛选、统计、房间列表、一键打卡、单人状态修改 | 对齐 `realname/headUrl/bedName`，学生卡展示床位 |
| `dorm_manager_check_history_view.dart` | 日期/楼栋/楼层筛选、详情、异常处理、导出 | 按当前历史结果计算统计；Excel 改为真实二进制保存 |
| `dorm_manager_makeup_audit_view.dart` | 列表、详情、通过、驳回 | 增加楼栋/状态筛选；驳回必须填写原因；展示申请时间与审批详情 |
| `dorm_manager_check_in_view.dart` | 本地 GPS 演示 | Swagger 中没有对应宿管上下班打卡接口，保持不作为真实后端入口 |

## Swagger 字段注意事项

- 首页床位字段为 `totalBedCount`，不是 `bedCount`。
- 首页未闭环异常字段为 `unhandledExceptionCount`。
- 房间学生姓名字段为 `realname`，床位字段为 `bedName`。
- 查寝详情异常原因字段为 `anomalyReason`。
- 补卡详情审批字段为 `approverName/approveTime/approveRemark`。
- Excel 导出直接返回文件字节，不返回 `{code,msg,data}` 或下载 URL。
- `dormitoryCheckStat` 不接受日期与楼栋筛选；历史页不能用它展示所选日期统计。

## 实现架构

- 宿管首页、按房间查寝、查寝历史、补卡审批的接口调用与业务状态统一收口到
  `DormitoryManagerController`，UI 不再直接调用仓库。
- 楼栋、楼层、通知、房间、历史和补卡筛选均由受控状态驱动；异步请求包含加载、
  错误、提交中和过期请求保护。
- 历史页和筛选后的房间页使用当前查询结果计算统计，避免错误复用不支持筛选条件的
  `/dormitoryCheckStat`。

## 真实账号验证

APP 账号在学校 `1111` 下的 `teacherRole.roles` 包含
`head_teacher,course_teacher,dormitory,manager`，可切换到宿管身份。
真实 `teacherRole` 响应是单个对象，而 Swagger 兼容场景可能返回数组；项目现已兼容
两种结构，避免宿管身份被漏掉。

当前 `dormitoryBuildingIds` 为空，因此宿管首页、房间、历史、补卡接口均正常
返回零数据；通知接口返回已发布通知。该账号适合验证宿管端空态、通知和筛选逻辑，
但无法验证会修改真实学生记录的一键打卡、单人状态修改、异常处理与补卡审批。
