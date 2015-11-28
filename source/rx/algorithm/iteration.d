module rx.algorithm.iteration;

import rx.primitives;
import rx.observer;
import rx.observable;

import std.range : put;

struct FilterObserver(alias f, TObserver, E)
{
public:
    this(TObserver observer)
    {
        _observer = observer;
    }

public:
    void put(E obj)
    {
        if (f(obj)) _observer.put(obj);
    }

    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
        }
    }

    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
        }
    }

private:
    TObserver _observer;
}
unittest
{
    alias TObserver = FilterObserver!(o => true, Observer!int, int);

    static assert( isObserver!(TObserver, int));
}

struct FilterObservable(alias f, TObservable)
{
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = FilterObserver!(f, TObserver, ElementType);
        static if (isSubscribable!(TObservable, ObserverType))
        {
            return _observable.subscribe(ObserverType(observer));
        }
        else static if (isSubscribable!(TObservable, Observer!ElementType))
        {
            return _observable.subscribe(observerObject!ElementType(ObserverType(observer)));
        }
        else
        {
            static assert(false);
        }
    }

private:
    TObservable _observable;
}
unittest
{
    import rx.subject;

    alias TObservable = FilterObservable!(o => true, Subject!int);

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception) { failureCount++; }
    }

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);
    auto disposable = observable.subscribe(TestObserver());
    assert(putCount == 0);
    sub.put(0);
    assert(putCount == 1);
    sub.put(1);
    assert(putCount == 2);
    disposable.dispose();
    sub.put(2);
    assert(putCount == 2);
}

template filter(alias f)
{
    FilterObservable!(f, TObservable) filter(TObservable)(ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!(n => n % 2 == 0);
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}
