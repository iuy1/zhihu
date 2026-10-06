# 零知识证明协议 Groth16 的原理

零知识证明是 Prover 向 Verifier 证明自己知道满足某些性质的信息，
但不泄露任何关于该信息的额外内容的过程。

Groth16 是 zk-SNARK (Zero-Knowledge Succinct Non-Interactive Argument of Knowledge)，
Non-Interactive 指 Prover 将证明发送给 Verifier 后，
Verifier 不需要继续向 Prover 询问就能验证正确性。
Succinct 指验证证明需要的计算量远小于（在渐进意义上）证明本身所描述的计算过程。

Groth16 是一种 r1cs（Rank-1 Constraint System）零知识证明协议。

## r1cs 是什么

所谓 Rank-1 指的是第 $i$ 个约束条件表示为
$$
\begin{aligned}
(& a^i_0 + \sum_{j=1}^n a^i_j I_j + \sum_{j=1}^m a^i_{n+j} W_{n+j}) \\
\cdot (& b^i_0 + \sum_{j=1}^n b^i_j I_j + \sum_{j=1}^m b^i_{n+j} W_{n+j}) \\
= & c^i_0 + \sum_{j=1}^n c^i_j I_j + \sum_{j=1}^m c^i_{n+j} W_{n+j}
\end{aligned}
$$
的形式，
其中 $I$ (instance) 是公开输入，
$n$ 是公开输入的数量，
$W$ (witness) 是私有输入，
$m$ 是私有输入的数量，
$a^i_j, b^i_j, c^i_j$ 双方都知道的常数，
所有的乘法和加法都在一个有限域中进行（模一个大质数）。

## r1cs 的例子

比如说 Prover 想证明他知道整数 $n$ 的两个因数，$p$ 和 $q$，
并告诉 Verifier 它们的差 $d$，但不想让 Verifier 知道两个因数本身是多少，
我们可以设计出这样的约束条件：

$$
\begin{aligned}
(0 + 0I_1 + 0I_2 + 1W_1 + 0W_2)
\cdot (0 + 0I_1 + 0I_2 + 0W_1 + 1W_2)
&= 0 + 1I_1 + 0I_2 + 0W_1 + 0W_2 \\
(1 + 0I_1 + 0I_2 + 0W_1 + 0W_2)
\cdot (0 + 0I_1 + 0I_2 + 1W_1 - 1W_2)
&= 0 + 0I_1 + 1I_2 + 0W_1 + 0W_2 \\
\end{aligned}
$$

约束条件的集合被称为”电路“。

根据两个因子的差计算出它们是多少是很容易的，
这个例子只是为了说明怎么把约束写成 r1cs 的形式。

如果认为 1 是真，0 是假，那么
$$
\begin{aligned}
x\land y &= x \cdot y \\
x\lor y &= x + y - x \cdot y \\
\lnot x &= 1 - x
\end{aligned}
$$
因此任何有限的计算过程都可以表示成 r1cs 的形式。

比如说我们可以将一个数按二进制拆分，从而实现比较大小运算，
这需要比较多的约束条件。

## Quadratic Arithmetic Programs

我们可以把所有约束合并成一个多项式

还是刚才的例子，电路的系数 $a,b,c$ 为：

$$
\begin{aligned}
& a^1_j = \{0,0,0,1,0\} &
& b^1_j = \{0,0,0,0,1\} &
& c^1_j = \{0,1,0,0,0\} &\\
& a^2_j = \{1,0,0,0,0\} &
& b^2_j = \{0,0,0,1,-1\} &
& c^2_j = \{0,0,1,0,0\} &
\end{aligned}
$$

我们把 $a^i_j$ 看成关于 $i$ 的函数，
根据拉格朗日插值，$n$ 个点可以唯一确定一个 $n-1$ 次多项式，
于是我们用一次多项式 $a_j(x)$ 来替换原来的 $a^i_j$，
得到：

$$
\begin{aligned}
a_j &= \{x-1, 0, 0, 2-x, 0\} \\
b_j &= \{0, 0, 0, x-1, 3-2x\} \\
c_j &= \{0, 2-x, x-1, 0, 0\}
\end{aligned}
$$

带入原来的约束条件得到：

$$
\begin{aligned}
(& (x-1) + 0I_1 + 0I_2 + (2-x)W_1 + 0W_2) \\
\cdot (& 0 + 0I_1 + 0I_2 + (x-1)W_1 + (3-2x)W_2) \\
= \space & 0 + (2-x)I_1 + (x-1)I_2 + 0W_1 + 0W_2
\end{aligned}
$$

规定 $A(x),B(x),C(x),P$ 为：
$$
\begin{aligned}
A(x) &= (x-1) + 0I_1 + 0I_2 + (2-x)W_1 + 0W_2 \\
B(x) &= 0 + 0I_1 + 0I_2 + (x-1)W_1 + (3-2x)W_2 \\
C(x) &= 0 + (2-x)I_1 + (x-1)I_2 + 0W_1 + 0W_2 \\
P(x) &= A(x) \cdot B(x) - C(x) = 0
\end{aligned} \\
$$

将 $x=1\space or\space 2$ 带入 $P$ 可以得到原来的两个约束条件，
也就是说，原来的两个约束条件成立等价于 $P$ 在 $1, 2$ 处的值为 $0$。

根据多项式的特性，$P$ 在 $x=1\space or\space 2$ 处的值为 $0$
等价于它是 $(x-1)(x-2)$ 的倍数，
多项式 $(x-1)(x-2)$ 记作 $T$ (target)，
它和输入 $I_i,W_i$ 是无关的。

例如，$I_1=15, I_2=2, W_1=5, W_2=3$，带入得到

$$
\begin{aligned}
A(x) &= -4x+9 \\
B(x) &= -x+4 \\
C(x) &= -13x+28 \\
P(x) &= 4x^2 - 12x + 8
\end{aligned} \\
$$

发现 $P(x)$ 确实是 $T(x)$ 的倍数，
记它们的商为 $H(x)=P(x)/T(x)$

实际上我们不需要从让 $x$ 从 $1$ 开始取，
从正确性上来说任意 $n$ 个点都是可以的，
实际应用中会使用 NTT 原根的幂次。

对于 $n$ 个约束的电路，
$T$ 的次数为 $n$，
$A,B,C$ 的次数为 $n-1$，
$P$ 的次数为 $2n-2$，
$H$ 的次数为 $n-2$。

对于知道 $W$ 值的 Prover 来说，$A,B,C,H$ 几个多项式是已知的，
对于 Verifier 来说，这几个多项式具体是什么并不重要，
Verifier 只关心 $A(x)\cdot B(x) = C(x) + H(x) \cdot T(x)$ 是否成立。

Verifier 可以随机选择一个 $\tau$ ，
如果关于几个多项式的等式在这一点上成立，
就相信等号两边的多项式是完全一样的。

如果 Prover 先得知 $\tau$ 的值，然后发送几个整数给 Verifier，
并声称它们就是 $A(\tau),B(\tau),C(\tau),H(\tau)$，
这当然是十分不可信的。

我们需要一种结构让 Prover 可以在不知道 $\tau$ 的情况下
计算这几个多项式的值，
防止 Prover 用另一组只在 $\tau$ 处让等式成立的多项式替换。

## 配对

为了简化公式，我们这样定义：

所有的数字被分为 4 种颜色：无色、红色、蓝色、紫色

- 只有同色的数字可以相加，不同色数字相加是没有意义的，
  例如
  $
  \color{red}{2}
  +\color{red}{3}
  =\color{red}{5}
  $
- 无色数字可以和任何颜色相乘，结果是另一个数字的颜色，例如
  $
  2\cdot\color{red}{3}
  =\color{red}{6}
  ,\space 3\cdot 4=12,\space 3\cdot\color{purple}{1}
  =\color{purple}{3}
  $
- 除了无色数字，其他的数字不能进行同色数除法，
  除法的结果是客观存在的，但是我们无法计算它，
  这对应椭圆曲线群和乘法群的离散对数假设。
- 红色乘蓝色得到紫色，对应配对操作，
  这是一种一般椭圆曲线不具备的性质，例如：
  $
  \color{red}{3}
  \cdot\color{blue}{7}
  =\color{purple}{21}
  $
- 类似地，无法计算紫色数除以红色或蓝色

无色数字代表标量，
红色和蓝色代表不同域上的椭圆曲线群，
紫色代表配对结果，它是一个有限域乘法群的子群，
这三个群拥有相同的阶，对应标量的模数，
如果你不知道椭圆曲线和有限域是什么也没关系 ~~（其实我也不懂）~~ ，
只需要记住上面几条规则就可以继续往下看了。

## Prover 计算多项式点值

假设 $A(x)$ 是一个 Prover 知道系数的二次多项式，
Verifier 希望 Prover 能计算
$
A(\tau)\cdot \color{red}{1}
=a_0\color{red}{1}
+a_1\tau\color{red}{1}
+a_2\tau^2\color{red}{1}
=a_0\color{red}{1}
+a_1\color{red}{\tau}
+a_2\color{red}{\tau^2}
$
，Verifier 只需要将
$
\color{red}{\tau}
,\color{red}{\tau^2}
$
发送给 Prover，注意同色数字不能计算除法，
Prover 无法反向计算
$
\color{red}{\tau}
/\color{red}{1}
=\tau
$

记
$
A(\tau)\cdot \color{red}{1}
=\color{red}{A}(\tau)
$ ，Verifier 将
$
\color{blue}{\tau}
,\color{blue}{\tau^2}
$
也发给 Prover，那么 Prover 就可以计算出全部
$
\color{red}{A}(\tau),
\color{blue}{B}(\tau),
\color{red}{C}(\tau),
\color{red}{H}(\tau),
\color{blue}{T}(\tau)$
，Verifier 可以验证
$
\color{red}{A}(\tau)\cdot
\color{blue}{B}(\tau) =
\color{red}{C}(\tau)\cdot
\color{blue}{1}+\color{red}{H}(\tau)\cdot
\color{blue}{T}(\tau)$

这样验证是可靠的吗？让我们试试

还是 $5*3=15,5-3=2$ 的例子，
比如说 Verifier 随机选择了 $\tau=100$，把
$
\color{red}{100}
,\color{blue}{100}
,\color{blue}{10000}
$
发给 Prover，Prover 计算出
$
\color{red}{A}(\tau) =
\color{red}{-391}
,\color{blue}{B}(\tau) =
\color{blue}{-96}
,\color{red}{C}(\tau) =
\color{red}{-1272}
,\color{red}{H}(\tau) =
\color{red}{4}
,\color{blue}{T}(\tau) =
\color{blue}{9702}
$

```py
(-391)*(-96) + 1272 - 4*9702
```

用 Python 验证得到 0

如果 Prover 实际上不知道 $A,B,C$ 呢，
比如 Prover 随便取
$
\color{red}{C}(\tau) =
10\cdot\color{red}{2}
,\color{red}{H}(\tau) =
\color{red}{2}
$
然后可以计算
$
\color{red}{C}(\tau)\cdot
\color{blue}{1}+\color{red}{H}(\tau)\cdot
\color{blue}{T}(\tau)=\color{purple}{19424}
$
，Prover 知道
$
\color{red}{A},\color{blue}{B}
$
相乘应该等于它，虽然 Prover 不能随便选一个
$\color{red}{A}$
然后反推出
$\color{blue}{B}$
，但可以把 $\color{red}{2}$ 提出来：
$
\color{red}{2}\cdot(10*\color{blue}{1}+\color{blue}{T}(\tau))
$
，为了防止 $\color{red}{A}$ 和 $\color{red}{H}$ 一样，
可以两边随便乘除比如说 $114$，
声称
$
\color{red}{A}(\tau) =
114\cdot\color{red}{2}
,\color{blue}{B}(\tau) =
1/114\cdot(10*\color{blue}{1}+\color{blue}{T}(\tau))
$

总之，只让 Prover 计算
$
\color{red}{A},\color{blue}{B}
$
完全无法确定 Prover 到底算了什么

## 改进

Verifier 可以通过引入两个新的随机数 $\alpha,\beta$
来解决这个问题。

Verifier 将
$
\color{red}{\alpha},\color{blue}{\beta}
$
发给 Prover，要求 Prover 计算
$
\color{red}{A}(\tau)+
\color{red}{\alpha}
$
和
$
\color{blue}{B}(\tau)+
\color{blue}{\beta}
$

这两部分相乘得到：

$
(
\color{red}{A}(\tau)\cdot
\color{red}{\alpha}
)
\cdot
(
\color{blue}{B}(\tau)\cdot
\color{blue}{\beta}
)=
\color{red}{A}(\tau)\cdot
\color{blue}{B}(\tau)+
\color{red}{\alpha}\cdot\color{blue}{B}(\tau)+
\color{blue}{\beta}\cdot\color{red}{A}(\tau)+
\color{red}{\alpha}\cdot\color{blue}{\beta}
$

带入 $A, B, C$ 应该满足的关系得到：

$
(\color{red}{A}(\tau)\cdot
\color{red}{\alpha}
)\cdot(\color{blue}{B}(\tau)\cdot
\color{blue}{\beta}
)=
\color{red}{\alpha}\cdot\color{blue}{\beta}
+\color{red}{\alpha}\cdot\color{blue}{B}(\tau)+
\color{blue}{\beta}\cdot\color{red}{A}(\tau)+
\color{red}{C}(\tau)\cdot\color{blue}{1}
+\color{red}{H}(\tau)\cdot
\color{blue}{T}(\tau)$

把
$
\color{red}{\alpha}\cdot\color{blue}{B}(\tau)=
\color{blue}{\alpha}\cdot\color{red}{B}(\tau)
$
翻过来后右边的蓝色部分就和电路输入无关了

考虑 Verifier 需要提供哪些值让 Prover 能计算等式右边剩余的部分

先看
$
\color{red}{A}(\tau)\cdot\color{blue}{\beta}
+\color{red}{B}(\tau)\cdot\color{blue}{\alpha}
+\color{red}{C}(\tau)\cdot\color{blue}{1}
$
，回顾
$$
\begin{aligned}
A(\tau) &=
A_0(\tau) + A_1(\tau) \cdot I_1 + A_2(\tau) \cdot I_2
+ A_3(\tau) \cdot W_1 + A_4(\tau) \cdot W_2 \\
B(\tau) &=
B_0(\tau) + B_1(\tau) \cdot I_1 + B_2(\tau) \cdot I_2
+ B_3(\tau) \cdot W_1 + B_4(\tau) \cdot W_2 \\
C(\tau) &=
C_0(\tau) + C_1(\tau) \cdot I_1 + C_2(\tau) \cdot I_2
+ C_3(\tau) \cdot W_1 + C_4(\tau) \cdot W_2
\end{aligned}
$$
如果允许 Prover 分别计算 $A,B,C$ ，
Prover 可能会偷偷地在计算时使用不同的 $W$ ，
所以我们把它们合并在一起，顺便简化验证过程：
$$
\begin{aligned}

\color{red}{A}(\tau)\cdot\beta
&+\color{red}{B}(\tau)\cdot\alpha
+\color{red}{C}(\tau) \\

= \color{red}{A_0}(\tau)\cdot\beta
&+\color{red}{B_0}(\tau)\cdot\alpha
+\color{red}{C_0}(\tau) \\

+ (\color{red}{A_1}(\tau)\cdot\beta
&+\color{red}{B_1}(\tau)\cdot\alpha
+\color{red}{C_1}(\tau))\cdot I_1 \\

+ (\color{red}{A_2}(\tau)\cdot\beta
&+\color{red}{B_2}(\tau)\cdot\alpha
+\color{red}{C_2}(\tau))\cdot I_2 \\

+ (\color{red}{A_3}(\tau)\cdot\beta
&+\color{red}{B_3}(\tau)\cdot\alpha
+\color{red}{C_3}(\tau))\cdot W_1 \\

+ (\color{red}{A_4}(\tau)\cdot\beta
&+\color{red}{B_4}(\tau)\cdot\alpha
+\color{red}{C_4}(\tau))\cdot W_2 \\

\end{aligned}
$$

$\alpha,\beta$ 对 Prover 来说应该是未知的，
如果 Prover 知道这两个变量中的某一个，
就可以找到另一组电路多项式 $A_j(x), B_j(x), C_j(x)$，
使它们的 $A_j(x)\cdot\alpha + B_j(x)\cdot\beta + C_j(x)$ 相同。

Verifier 把
$
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)
$
发给 Prover，Prover 就可以完成这一部分的计算，
Prover 只需要计算 $W$ 项，
常数项和 $I$ 项由 Verifier 来计算。

然后是
$
\color{red}{H}(\tau)\cdot
\color{blue}{T}(\tau)$
部分，根据前面的例子我们知道，$T$ 和电路输入无关，
只和电路的结构有关，既然前面 Verifier 提供的信息已经和电路有关，
这部分也一起简化一下：

$$
\begin{aligned}
&\color{red}{H}(\tau)\cdot T(\tau) \\
=&H_0\cdot\color{red}{T}(\tau)
+H_1\cdot\tau\cdot\color{red}{T}(\tau)
+H_2\cdot\tau^2\cdot\color{red}{T}(\tau)
\end{aligned}
$$

（在只有两个约束的电路中只会用到常数项，多写两项是为了方便理解）

### 例子

还是 $5*3=15,5-3=2$ 的例子，
Verifier 随机选择 $\tau, \alpha,\beta$，把
$$
\color{red}{\tau},\color{blue}{\tau},
\color{red}{\alpha},\color{blue}{\beta}, \\

\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)(j\in{0..4}) \\
=\{
(\tau-1)\cdot\color{red}{\alpha},
(-\tau+2)\cdot\color{red}{1},
(\tau-1)\cdot\color{red}{1}, \\
(-\tau+2)\cdot\color{red}{\alpha}
+(\tau-1)\cdot\color{red}{\beta},
(-2\tau+3)\cdot\color{red}{\beta},\}, \\

\{
\color{red}{T}(\tau),
\tau \cdot\color{red}{T}(\tau),
\tau^2 \cdot\color{red}{T}(\tau)\} \\
=\{
(\tau-1)\cdot(\tau-2)\cdot\color{red}{1},
(\tau-1)\cdot(\tau-2)\cdot\tau
\cdot\color{red}{1},(\tau-1)\cdot(\tau-2)\cdot\tau^2
\cdot\color{red}{1}
\}
$$

发给 Prover，Prover 计算出

$$
\begin{aligned}
\color{red}{\pi_A}&=-4\color{red}{\tau}
+\color{red}{9}+\color{red}{\alpha} \\

\color{blue}{\pi_B}&=-\color{blue}{\tau}
+\color{blue}{4}+\color{blue}{\beta} \\

\color{red}{W}&=((-\tau+2)\cdot\color{red}{\alpha}
+(\tau-1)\cdot\color{red}{\beta})W_1 \\
&+((-2\tau+3)\cdot\color{red}{\beta})W_2 \\
&=
(-5\tau+10)\cdot\color{red}{\alpha}
+(-\tau-4)\cdot\color{red}{\beta} \\

\color{red}{H}&=
4\cdot(\tau-1)\cdot(\tau-2)\cdot\color{red}{1} \\

\color{red}{\pi_C}&=\color{red}{W}+\color{red}{H}\end{aligned}
$$

发送证明
$
\pi = \{
\color{red}{\pi_A},\color{blue}{\pi_B},\color{red}{\pi_C}
\}
$
给 Verifier，Verifier 计算
$$
\begin{aligned}
\color{red}{I}&=(\tau-1)\cdot\color{red}{\alpha}
+I_1\cdot(-\tau+2)\cdot\color{red}{1}
+I_2\cdot(\tau-1)\cdot\color{red}{1} \\
&=
(\tau-1)\cdot\color{red}{\alpha}
+(-13\tau+28)\cdot\color{red}{1}
\end{aligned}
$$
验证
$$
\color{red}{\pi_A}\cdot\color{blue}{\pi_B}
=\color{red}{\alpha}\cdot\color{blue}{\beta}
+\color{red}{I}\cdot\color{blue}{1}
+\color{red}{\pi_C}\cdot\color{blue}{1}
$$

在这个例子中，等式两边都等于

$$
(
\alpha\cdot\beta
+\alpha(-\tau+4)
+\beta(-4\tau+9)
+4\tau^2-25\tau+36
)\cdot\color{purple}{1}
$$

## 改进 2

即使 Verifier 不把
$$
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)$$
中关于 $I$ 的部分发给 Prover，
Prover 也可能因为 $I_j$ 和某些 $W_j$ 拥有完全相同的系数
能计算出 $\color{red}{I}$

如果 Prover 计算出了 $\color{red}{I}$ ，
就能构造假证明
$$
\pi = \{
\color{red}{\pi_A}=\color{red}{\alpha},
\color{blue}{\pi_B}=\color{blue}{\beta},
\color{red}{\pi_C}=-\color{red}{I}\}
$$

我们再引入两个随机数 $\gamma,\delta$ ，
将
$$
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)$$
分成两部分，$I$ 部分改成
$$
\frac{
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)}{\gamma}
$$
$W$ 部分改成
$$
\frac{
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)}{\delta}
$$
算出来 $I,W$ 是原来的 $1/\gamma,1/\delta$ ，
相应的验证过程改为
$$
\color{red}{\pi_A}\cdot\color{blue}{\pi_B}
=\color{red}{\alpha}\cdot\color{blue}{\beta}
+\color{red}{I}\cdot\color{blue}{\gamma}
+\color{red}{\pi_C}\cdot\color{blue}{\delta}
$$

$\color{red}{\pi_C}$ 中还包含 $\color{red}{H}$ 部分，
类似地，把
$\tau^j\cdot\color{red}{T}(\tau)$
改成
$\frac{\tau^j\cdot\color{red}{T}(\tau)}{\delta}$

Prover 不知道 $1/\delta$ ，
因此只有使用 Verifier 提供的带有 $1/\delta$ 的项
才能得到有意义的
$
\color{red}{\pi_C}\cdot\color{blue}{\delta}
$

在 Groth16 最初的论文中， $\gamma$ 是随机生成的，
在 zcash 的实现中， $\gamma$ 固定取 $1$

## 改进 3

验证证明的过程实际上不需要用到
$\tau,\alpha,\beta,\gamma,\delta$
，同一个电路可以使用同一套参数，
后续的证明不再需要交互。

## 改进 4

回顾刚才 Prover 生成证明的过程，
我们发现其中没有使用任何随机数，
这意味着完全相同的输入 $I,W$ 会生成完全相同的证明。

如果有攻击者通过某种方式确定输入在一个很小的范围内，
攻击者就可以枚举所有可能的输入，检查产生的证明是否相同，
这样就导致 Prover 的私有输入被泄露。

并且不同证明的
$
\color{red}{A}(\tau),
\color{blue}{B}(\tau)$
部分可以被攻击者差分，
如果两个证明的输入差别很小，
相应的特征也会泄漏。

假设 Prover 随机生成 $R,T$ ，加到
$
\color{red}{\pi_A},\color{blue}{\pi_B}
$
上，那么 Verifier 需要验证的等式变为

$$
(\color{red}{A}
(\tau)+\color{red}{\alpha}
+\color{red}{R})\cdot

(\color{blue}{B}
(\tau)+\color{blue}{\beta}
+\color{blue}{T}) \\

=\color{red}{\alpha}\cdot\color{blue}{\beta}
+\color{red}{I}\cdot\color{blue}{\gamma}
+\color{red}{\pi_C}\cdot\color{blue}{\delta}

+(\color{red}{A}(\tau)+\color{red}{\beta})\cdot
\color{blue}{R}+(\color{red}{B}(\tau)
+\color{red}{\alpha})\cdot
\color{blue}{T}+R\cdot T\cdot\color{purple}{1}
$$

为了方便把这两个随机数合并到
$\color{red}{\pi_C}$
中，我们让多出来的这部分都是
$\color{blue}{\delta}$
的倍数

也就是说，让 Prover 随机生成 $s,t$ ，
令 $R=r\cdot\delta,T=t\cdot\delta$

$R,T$ Prover 不能直接计算的，
但可以计算
$\color{red}{R},\color{blue}{T}$

等式右部多出来的部分可以重写为
$$
(
(\color{red}{A}(\tau)+\color{red}{\beta})\cdot r
+(\color{red}{B}(\tau)+\color{red}{\alpha})\cdot t
+\color{red}{R}\cdot t
)
\cdot\color{blue}{\delta}
$$

验证方式和之前一样

## 总结

### 初始化

1\. 计算 $A_j(x), B_j(x), C_j(x), T(x)$ 多项式

2\. 随机生成 **simulation trapdoor**：
$$ST = \{\alpha, \beta, \gamma, \delta, \tau\}$$

3\. 计算 **Common Reference String**：
$$
CRS = \left\{
\begin{aligned}
&\color{red}{\alpha},\color{red}{\beta},\color{red}{\delta},
\tau^j\cdot\color{red}{1},\tau^j\cdot\color{red}{T}(\tau)\\
&\tfrac{
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)}{\gamma}(j\in{0..n}),\\

&\tfrac{
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)}{\delta}(j\in{n+1..n+m}), \\

&\color{blue}{\beta},\color{blue}{\gamma},\color{blue}{\delta},
\tau^j\cdot\color{blue}{1} \\
\end{aligned}
\right\}
$$

4\. 删除 **simulation trapdoor**

初始化步骤可以由 Verifier 或可信第三方完成，
也可以通过 MPC(多方计算) 完成，
Prover 不应该知道 trapdoor 的值。

### Prover

随机生成 $r,t$ ，计算

$$
\begin{aligned}
\color{red}{\pi_A}&=\color{red}{A}(\tau)+\color{red}{\alpha}
+r\cdot\color{red}{\delta} \\

\color{blue}{\pi_B}&=\color{blue}{B}(\tau)+\color{blue}{\beta}
+t\cdot\color{blue}{\delta} \\

\color{red}{W}&=\sum_{j=1}^{m}
W_j\cdot
\frac{
\color{red}{A_{j+n}}(\tau)\cdot\beta
+\color{red}{B_{j+n}}(\tau)\cdot\alpha
+\color{red}{C_{j+n}}(\tau)}{\delta} \\

\color{red}{H}&=\color{red}{H}(\tau)\cdot T(\tau) \\

\color{red}{\pi_C}&=
\color{red}{W}+\color{red}{H}+
(\color{red}{A}(\tau)+\color{red}{\beta})\cdot r
+(\color{red}{B}(\tau)+\color{red}{\alpha})\cdot t
+r\cdot t\cdot\color{red}{\delta}
\end{aligned}
$$

证明为

$$
\pi = \{
\color{red}{\pi_A},\color{blue}{\pi_B},\color{red}{\pi_C}
\}
$$

### Verifier

计算

$$
\color{red}{I}=\frac{
\color{red}{A_0}(\tau)\cdot\beta
+\color{red}{B_0}(\tau)\cdot\alpha
+\color{red}{C_0}(\tau)}{\gamma} \\
+\sum_{j=1}^{n}
I_j\cdot
\frac{
\color{red}{A_j}(\tau)\cdot\beta
+\color{red}{B_j}(\tau)\cdot\alpha
+\color{red}{C_j}(\tau)}{\gamma}
$$

验证

$$
\color{red}{\pi_A}\cdot\color{blue}{\pi_B}
=\color{red}{\alpha}\cdot\color{blue}{\beta}
+\color{red}{I}\cdot\color{blue}{\gamma}
+\color{red}{\pi_C}\cdot\color{blue}{\delta}
$$

验证消耗的时间只和公开输入数量有关，
和私有输入、约束的数量无关。

## 参考资料 & 扩展阅读

- [zhihu/wib-85/Groth16(1)](https://zhuanlan.zhihu.com/p/2072066930417071578)
- [ECC pairing in Python](https://github.com/ethereum/py_ecc)
- [circom](https://github.com/iden3/circom)
- [moonmath.pdf,介绍zk-snark原理](https://github.com/LeastAuthority/moonmath-manual)
- [oi-wiki/ntt](https://oi-wiki.org/math/poly/ntt/)
- [Veil Cash Groth16 Forgery](https://www.darknavy.org/web3/exploits/veil-cash-groth16-forgery/)
- [Groth16 论文](https://eprint.iacr.org/2016/260.pdf)
