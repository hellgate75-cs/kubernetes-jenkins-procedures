import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.Future

def list = []
def myClosure = {num -> println "I Love Groovy ${num}"; list.add(num)}
def parallelClosure(closure, maxPool) {
  def threadPool = Executors.newFixedThreadPool(maxPool)
   try {
    List<Future> futures = (1..20).collect{num->
      threadPool.submit({->
      closure num } as Callable);
    }
    // recommended to use following statement to ensure the execution of all tasks.
    futures.each{ it.get() }
  }finally {
    threadPool.shutdown()
  }
}
parallelClosure(myClosure, 5)
println "Execution list ${list}"