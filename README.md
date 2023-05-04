## 实验环境：
处理器：英特尔® 至强® Gold 6248R 处理器
内存：263685716kB

## 优化分析
### 程序结构：
``` bash
.
├── bin
│   └── stencil
├── check.png
├── check.txt
├── data.txt
├── include
│   ├── pngconf.h
│   ├── png.h
│   └── pnglibconf.h
├── IPCC.png
├── lib
│   ├── libpng16.a
│   └── libz.a
├── Makefile
├── output.png
├── src
│   ├── image.cc
│   ├── image.h
│   ├── image.o
│   ├── main.cc
│   ├── main.o
│   ├── stencil.cc
│   ├── stencil.h
│   └── stencil.o
└── tree.txt

4 directories, 21 files

```
### 主程序入口：
main.cc为主程序入口
``` c++
// 检测循环

    for (int iTrial = 1; iTrial <= nTrials; iTrial++)
    {
        // 一轮开始时间
        const double t0 = wtime();

        ApplyStencil(img_in, img_out);
        
        // 一轮结束时间
        const double t1 = wtime();

        // 一轮总时间
        const double ts = t1 - t0;     // time in seconds
        const double tms = ts * 1.0e3; // time in milliseconds

        t += tms;
        dt += tms * tms;

        printf("%5d %15.3f \n", iTrial, tms);
        fflush(stdout);
```

其中，主要的计算集中于`ApplyStencil(img_in, img_out)`函数，所以针对应该针对该函数进行优化。
### 热点函数
```c++
void ApplyStencil(ImageClass<P> & img_in, ImageClass<P> & img_out) {

  const int width  = img_in.width;
  const int height = img_in.height;

  P * in  = img_in.pixel;
  P * out = img_out.pixel;
 
    for (int j = 1; j < width-1; j++) {
      for (int i = 1; i < height-1; i++) {
    int im1jm1 =(i-1)*width + j-1;
    int im1j   =(i-1)*width + j;
    int im1jp1 =(i-1)*width + j+1;
    int ijm1   =(i  )*width + j-1;
    int ij     =(i  )*width + j;
    int ijp1   =(i  )*width + j+1;
    int ip1jm1 =(i+1)*width + j-1;
    int ip1j   =(i+1)*width + j;
    int ip1jp1 =(i+1)*width + j+1;
    P val =
      -in[im1jm1] -   in[im1j] - in[im1jp1]
      -in[ijm1]   +   8*in[ij] - in[ijp1]
      -in[ip1jm1] -   in[ip1j] - in[ip1jp1];
  
    val = (val < 0   ? 0   : val);
    val = (val > 255 ? 255 : val);

    out[i*width + j] = val;
      }
  }
}
```
该函数为热点函数。
其中的for循环为重点优化对象。
### 优化思路
1. 针对C++语言特性，修改二层循环，将原本的列优先修改为行优先
2. 针对for循环进行循环优化
### 优化后代码
```c++
#pragma omp parallel for num_threads(256)
    for (int i = 1; i < height - 1; i++)
    {
        for (int j = 1; j < width - 1; j++)
        {
            int im1jm1 = (i - 1) * width + j - 1;
            int im1j = (i - 1) * width + j;
            int im1jp1 = (i - 1) * width + j + 1;
            int ijm1 = (i)*width + j - 1;
            int ij = (i)*width + j;
            int ijp1 = (i)*width + j + 1;
            int ip1jm1 = (i + 1) * width + j - 1;
            int ip1j = (i + 1) * width + j;
            int ip1jp1 = (i + 1) * width + j + 1;
            P val =
                -in[im1jm1] - in[im1j] - in[im1jp1] - in[ijm1] + 8 * in[ij] - in[ijp1] - in[ip1jm1] - in[ip1j] - in[ip1jp1];

            val = (val < 0 ? 0 : val);
            val = (val > 255 ? 255 : val);
            out[i * width + j] = val;
        }
    }
}
```
## 优化结果
### Makefile
```makefile
CXX         =   g++
CXXFLAGS    =   -Iinclude/
CXXFLAGS    +=  -no-pie
CXXFLAGS    +=  -fopenmp -O3 -ffast-math
LDFLAGS     =   lib/libpng16.a lib/libz.a
OBJECTS     =   src/main.o src/image.o src/stencil.o
stencil: $(OBJECTS)
    $(CXX)  $(CXXFLAGS) -o bin/stencil $(OBJECTS) $(LDFLAGS)
all:    stencil
run:    all
    bin/stencil test-image.png
clean:
    rm -f $(OBJECTS) bin/stencil output.png src/*~ *~
```
### 优化前
```

[1mEdge detection with a 3x3 stencil[0m

Image size: 10410 x 5905

[1mTrial        Time, ms 
    1        2037.002 
    2        2036.398 
    3        2040.488 
    4        2036.473 
    5        2036.530 
    6        2036.633 
    7        2040.433 
    8        2036.315 
    9        2036.442 
   10        2036.436 
-----------------------------------------------------
Total :    20373.2 ms
-----------------------------------------------------

Output written into data.txt and output.png

```
### 优化后
```

[1mEdge detection with a 3x3 stencil[0m

Image size: 10410 x 5905

[1mTrial        Time, ms 
    1          20.006 
    2          15.099 
    3          15.854 
    4          15.044 
    5          15.002 
    6          14.832 
    7          14.620 
    8          14.724 
    9          14.484 
   10          14.420 
-----------------------------------------------------
Total :      154.1 ms
-----------------------------------------------------

Output written into data.txt and output.png

```
本次优化没有循环展开和向量化优化以及更深层次的优化，只进行了循环优先级的改变和并行优化，以及开启了GCC的编译优化。总体来说，性能得到了20373/154≈**130倍**的性能提升
