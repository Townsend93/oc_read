//
//  main.m
//  Object
//
//  Created by tc on 2021/12/15.
//

// 1. 对象分析
// 2.


#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>
// 不同平台的代码不一样

// 生成c++ 代码
//xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main-arm64.cpp
int main(int argc, char * argv[]) {
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
        
        NSObject *person = [[NSObject alloc] init];
        // 获取NSObject类实例对象内存大小
        NSLog(@"%zd",class_getInstanceSize([NSObject class]));//8
        // 获取指针指向的对象的内存大小 (CoreFoundation 规定至少16个字节)
        NSLog(@"%zd",malloc_size((__bridge const void*)person));//16
        
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

#pragma mark - 对象

// 内存对齐： 结构体的大小必须是最大成员大小的倍数

// OC NSObject 对象其实就是c++ 结构体

// Class 就是一个指向结构体的指针
struct NSObject_IMPL {
    Class isa;
};

//allocWithZone

//class_createInstance

// unalignSize = unalignInstanceSize  未对齐大小
// alignSize = alignInstanceSize(unalgnSize) 对齐大小
// size = instanceSize(alignSize) 需要占用的大小,

//calloc(1,size) 实际分配的大小
// Buckets sized {16, 32, 48, 64, 80, 96, 112} 最优内存大小 16的倍数, ios操作系统内存对齐

#pragma mark - 对象问题答疑

// OC NSObject 对象的内存大小
// 问题1：NSObject对象占多少个字节
// 答：16个字节. 但是NSObject对象内部只使用了8个字节
// 通过class_getInstanceSize获取到实例大小为8(内存对齐过的大小)，但是oc 规定oc对象最小为16. 可通过malloc_size 获取指针指向的内存实际大小为16.




//1. instance 实例对象 (isa , 其他成员变量)
//2. class 类对象 (isa, superclass, 属性、、协议、方法信息等)(同一个类的类对象内存中只存储一份)
//3. meta-class (isa, superclass, 类方法)元类对象(描述类对象的对象)  (元数据：描述数据的数据)


/*
 1. Class objc_getClass(const char *aClassName)
 1> 传入一个字符串类名
 2> 返回对硬的类对象
 
 2. Class object_getClass(id obj)
 1> 传入的obj可能是instance对象，class对象、meta-class对象
 2> 如果传入instance对象，返回class 对象，如果是class对象则返回meta-class对象，如果传入meta-class对象，返回NSObject（基类）的meta-class对象
 
 
 */


//superclass 指向父类类对象
/*
 实例方法调用流程
 1. instance实例对象 通过instance中的isa找到类对象，类对象中没有找到就通过类对象的superclass 找到父类类对象，依次类推.
 */


// instance 的isa 指向class， class的isa 指向 meta-class, 元类都指向root class， 基类对象的isa指向自己
// class 的superclass 指向 父类， 依次到root class， root class 的superlclass为nil
// 元类的superclass 和class一样，只是到 root meta-class的superclass指向 rootclass



#pragma mark - KVO 实现

//1.KVO 如何实现？
// 利用runtime 动态生成该对象的一个子类，并且让instance对象的isa指向这个子类的类对象
// 在该子类的类对象中也有一个被监听属性的setter方法， 当instance对象修改属性时，就会调用新子类中的setter方法，在这个子类的setter方法中会调用Foundation中的_NSSetXXXValueAndNotify()函数

// _NSSetXXXValueAndNotify 函数内部逻辑如下：
// willChangeValueForKey
// 利用[super set]，调用父类原来的setter方法
// didChangeValueForKey， (didChangeValueForKey函数内部触发 监听器(oberser)的监听方法 (oberserValueForKeyPath))

//2. 本质其实就是利用 替换重写setter方法达到目的，直接修改成员变量不会触发KVO


#pragma mark - KVC

//setValue:forKey:
//1. 先去依次按顺序查找方法  setKey, _setKey, 有则调用
//2. 没有查找到方法时 调用accessInstanceVariablesDirecty函数查看是否可以直接访问成员变量
//3. 如果不允许则调用 setValue:forUndefinedKey:

//4.如果允许访问成员变量则依次按顺序查找成员变量 _key, _isKey, key, isKey, 找到则赋值

//5. 没找到则调用 setValue:forUndefinedKey:

// 问题1：kvc会触发kvo吗？
// 会触发kvo(无论是否有setter方法都会触发, 因为kvc内部直接赋值成员变量时也调用了willChangeValueForKey，didChangeValueForKey)


//value:forKey 同理

#pragma mark - Category

// 源码顺序
//1.objc-os.mm   _objc_init -> map_images -> map_images_nolock

//2. objc-runtime-new.mm    _read_images -> remethodizeClass -> attachCategories -> attachlists -> realloc,memmove, memcpy

// 利用runtime 将类的所有的category 加载在一个category 数组中，将每次的数据插入到最前面，也就是说最后编译的category 在最前面，然后将这些category数组数据合并到类对象中，并放在最前面（也就解释了为什么category的方法优先级高，多个category存在同一个方法会调用最后编译的category中的方法）

// category_list = [category3, category2, category1]
// [category_list, 原来的方法]

// category 和 extension的区别
// extension 是在编译的时候，他的数据就已经包含在类对象信息中了
// category 是在运行时，才会将数据合并到类对象信息中


//+load 方法
//1. 先调用类的load,
//2. 再调用category 的load

//load 调用源码顺序
//1.先调用 call_class_method(), 在loadable_classes 数组中先添加父类，再加子类，所有先调用父类的load，再调用子类的load (在遍历时是通过函数地址直接调用load)
//2. call_category_method(), category 按编译顺序调用,不区分父类子类


//+initialize   类第一次接收消息的时候调用 （通过消息机制objc_msgSend调用）
// 顾名思义 这是类的初始化会先调用父类的 再调用子类的，如果分类实现了，会覆盖类的initialize
// 如果子类没有实现initialize 会调用父类的initialize （父类的initialize可能会调用多次）

// load 与initialize的区别
// initialize 是通过objc_msgSend 调用,再一次接收消息时调用，load是通过函数地址直接调用
//


// category 能否添加成员变量？
// 在category_t 结构体中没有可存储成员变量的容器,所以不能添加成员变量
// 可通过runtime 中的属性关联函数来间接达到添加成员变量的目的

// 属性关联，runtime通过维护全局的一个map，以关联对象的地址为key，关联信息为value

#pragma mark - Block

/*
 
 int age = 20;
 void(^block)(void) =^{
    NSLog(@"age is %d",age);
 };
 
struct __main_block_impl {
    struct __block_impl impl;
    struct __main_block_desc desc;
};

struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};
// block 描述信息
struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
};

static void __main_block_func_0 {
    
}
*/

//Block 类型
//Global: 没有访问auto变量



//Stackblock 不会强引用对象(block自己都是随时可能销毁，没必要强引用其他对象了)

//如果block被拷贝到堆上时
// block 会调用内部的copy函数
// 这个copy函数会调用_Block_object_assign函数
// 这个函数会根据auto变量的修饰符(__strong, __weak,)做出相应的操作

//如果block从堆上移除时
// 会调用block内部dispose函数
// dispose 内部调用_Block_objec_dispose函数
//_Block_objec_dispose 会自动释放引用的auto变量，类似release


#pragma mark - Method

struct method_t {
    SEL name;  // 函数名称
    const char *types; // 函数返回值、参数类型
    IMP imp; // 函数实现指针
};



#pragma mark - 消息机制 objc_msgSend

/*
 1. 消息发送 (正常查找)
 
 a. 判断消息接收者是否为nil，如果nil直接退出
 b. 通过接收者的isa找到类对象, 去类对象中的(cache)方法缓存中查找, 找到就调用
 c. 类对象缓存中没找到就去方法列表中查找，找到就添加缓存并调用
 d. 类对象缓存也没找到，就判断父类是否为nil(通过类对象的superclass 查找)，没找到就结束这个阶段
 e. 有父类的话就先查找父类的方法缓存，有就调用并且在当前类对象缓存
 f. 所有的父类都没有就进入下一阶段
*/

/*
 2. 动态方法解析 (是否动态添加方法)
 
 a. 判断是否已经动态解析
 b. 通过resolveInstanceMethod 或者resolveClassMethod 动态添加方法
*/


/*
 3. 消息转发 (转发给其他对象来处理消息)
 
 a. forwardingTargetForSelector, 返回另一个消息接收者，重新走消息发送流程
 b. methodSignatureForSelector 返回一个方法签名说明有方法处理，就会去调用forwardInvocation,不返回的话就会直接抛出错误
 c. 在 forwardInvocation 中可以随便干啥
*/
