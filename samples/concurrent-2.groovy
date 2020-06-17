import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.Future
def numbers = []
(1..20).collect {n -> numbers.add(n)}
def list = []
def myClosure = {num -> println "I Love Groovy ${num}"; list.add(num)}
def parallelClosure(array, closure, maxPool) {
  def threadPool = Executors.newFixedThreadPool(maxPool)
   try {
    List<Future> futures = array.collect {num->
      threadPool.submit({->
      closure num } as Callable);
    }
    // recommended to use following statement to ensure the execution of all tasks.
    futures.each{ it.get() }
  }finally {
    threadPool.shutdown()
  }
}
parallelClosure(numbers, myClosure, 5)
println "Execution list ${list}"
