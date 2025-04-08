# lua-await
* 基于lua coroutine实现的异步任务池

## Reference
* https://github.com/cloudwu/skynet/blob/master/lualib/skynet.lua

## Design
```bash
1. 核心业务逻辑仍运行在主协程（如DS的Update，各个模块的Tick等），旨在提供一个独立的Lib，使开发者可以用编写同步代码的方式替代callback嵌套callback来处理复杂的异步逻辑
2. 提供coroutine复用和gc支持
3. await.Wait和await.Wakeup是该库的核心接口，可通过指定token挂起和唤醒对应coroutine，await.Call、await.Sleep也是基于这俩接口实现
```

## Api
* await.Run(f, ...)  将指定函数传入任务池中执行，该接口只能在主协程中调用
* await.Call(rpcInvoke, ...)  发起rpc调用并获取返回值，该接口只能在任务池中调用. 需按照function (callback, ...)格式提供rpcInvoke参数，对rpc具体实现无侵入
* await.Sleep(timeoutInvoke, ti)  休眠指定时长，该接口只能在任务池中调用. 需按照function (ti, callback)格式提供timeoutInvoke参数，对timeout具体实现无侵入
* await.Fork(f)  在当前任务中创建一个新任务，当前任务执行完成或挂起后再执行f，该接口只能在任务池中调用
* await.Wait(token)  根据传入token挂起当前coroutine，默认token为当前coroutine，该接口只能在任务池中调用
* await.Wakeup(token)  根据传入token唤醒对应coroutine，该接口在主协程和任务池中都可调用

## Run Test
```bash
lua example/main.lua
```