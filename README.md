# ICIC666
集创赛紫光同创（1）

---

## 论文精定位实现原理

### 论文来源
《Design and Implementation of License Plate Positioning Algorithm based on FPGA》

---

### 精定位流程概述

粗定位（双通道掩膜 + 灰度-中值-Sobel-膨胀融合）完成后，得到包含车牌区域的二值边缘图像。  
精定位在此基础上，通过**水平投影 + 垂直投影 + 三阶矩阵法**确定车牌的四条精确边界。

---

### 一、水平投影与垂直投影

**水平投影**：对二值图像逐行统计白色像素（=1）的数量，得到每行的累计值 N(y)：

```
N(y) = Σ f(x, y)    （对所有列 x 累加）
```

**垂直投影**：对二值图像逐列统计白色像素的数量，得到每列的累计值 N(x)。

- 水平投影 N(y) 用于确定车牌的**上下边界**（Yup / Ydown）
- 垂直投影 N(x) 用于确定车牌的**左右边界**（Xleft / Xright）

---

### 二、三阶矩阵法定位边界

#### 1. 构造 3×3 数据矩阵 F

以 **9 拍滑动窗口**遍历投影值序列，取相邻 9 个值构成 3×3 矩阵 F：

```
F = | N(y1)  N(y2)  N(y3) |
    | N(y4)  N(y5)  N(y6) |
    | N(y7)  N(y8)  N(y9) |
```

其中 y1 < y2 < … < y9 为连续行坐标，y5 为窗口中心行。

#### 2. 三阶矩阵算子 F1

```
F1 = | 1  1  0 |
     | 1  1  0 |
     | 1  0  0 |
```

#### 3. 矩阵相乘 K = F × F1

取 K 的第 1 行之和 T1 与第 3 行之和 T2（化简结果）：

```
T1 = K(1,1) + K(1,2) + K(1,3) = 2·N(y1) + 2·N(y2) + N(y3)
T2 = K(3,1) + K(3,2) + K(3,3) = 2·N(y7) + 2·N(y8) + N(y9)
```

T1 反映窗口**顶部区域**的边缘强度，T2 反映窗口**底部区域**的边缘强度。

#### 4. 阈值计算

```
Threshold = (Σ Nk) / M
```
其中 k 为累计值不为零的行/列索引，M 为这些行/列的总数，Nk 为对应的累计值。

#### 5. 边界判定准则

| 条件 | 含义 | 对应边界 |
|---|---|---|
| `T1 < Threshold` 且 `T2 > 5×Threshold` | 有效上升沿 | **第一次**出现时，y5 = **Ydown**（下边界） |
| `T1 > 5×Threshold` 且 `T2 < Threshold` | 有效下降沿 | **最后一次**出现时，y5 = **Yup**（上边界） |

同理，对垂直投影 N(x) 做相同处理，可得到左边界 Xleft 和右边界 Xright。

---

### 三、FPGA 模块实现（本仓库新增）

| 文件 | 功能 |
|---|---|
| `img_process/h_projection.v` | 水平投影：逐行累加白像素，行结束输出 `proj_row_val[N(y)]` 和 `proj_row_idx` |
| `img_process/v_projection.v` | 垂直投影：帧内 RMW 流水累加列计数，帧结束后顺序输出 `proj_col_val[N(x)]` |
| `img_process/boundary_detect.v` | 三阶矩阵法边界检测：接收投影流，计算阈值，9 拍滑动窗口判断 T1/T2，输出 `boundary_lo`（Ydown/Xleft）和 `boundary_hi`（Yup/Xright） |

**典型连接方式：**

```
dilate_data (1-bit)
    ├─→ h_projection → proj_row_* → boundary_detect → Yup, Ydown
    └─→ v_projection → proj_col_* → boundary_detect → Xleft, Xright
```
