# lua-await
* 基于lua coroutine实现的异步任务池

## Design
```bash
1. 核心业务逻辑仍运行在主协程（如DS的Update，各个模块的Tick等），旨在提供一个独立的Lib，使开发者可以用编写同步代码的方式替代callback嵌套callback来处理复杂的异步逻辑
2. 提供coroutine复用和gc支持
3. await.Wait 和 await.Wakeup是该库的核心接口，await.Call、await.Sleep都是基于这俩接口实现，并跟timeout或rpc机制解耦
```

## Api
* await.Run(f, ...)  将指定函数传入任务池中执行，该接口只能在主协程中调用
* await.Call(rpcInvoke, ...)  发起rpc调用并获取返回值，对rpc实现无侵入，该接口只能在任务池中调用
* await.Sleep(timeoutInvoke, ti)  休眠指定时长，对timeout实现无侵入，该接口只能在任务池中调用
* await.Fork(f)  在当前任务中创建一个新任务，当前任务执行完成或挂起后再执行f，该接口只能在任务池中调用
* await.Wait(token)  根据传入token挂起当前coroutine，默认token为当前coroutine，该接口只能在任务池中调用
* await.Wakeup(token)  根据传入token唤醒对应coroutine

## Run Test
```bash
lua example/main.lua
```