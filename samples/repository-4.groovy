import groovy.json.*; 
import org.json.JSONObject; 
import groovy.json.JsonSlurper;
import groovy.json.JsonBuilder;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.Future;
def get(def url) {
    def personalAccessToken = "CKxDxsG9yU-gGD5wCNL1";  //cs-infra
    def connection = new URL(url).openConnection() as HttpURLConnection;
    connection.setRequestMethod("GET");
    connection.setRequestProperty("PRIVATE-TOKEN", personalAccessToken);
    //connection.setInstanceFollowRedirects(true);
    //connection.setReadTimeout(60000);
    connection.setConnectTimeout(60000);
    connection.connect();
    assert connection.getResponseCode() == 200;
	return connection.getInputStream().getText();
}
def jsonParse(def json){
    return new groovy.json.JsonSlurper().parseText(json);
    //return readJSON(file: '', text: json)
}

def getProjects(def groupId) {
    def baseUrl = "https://gitlab.com/api/v4";
	def ret = [];
	String url = "${baseUrl}/groups/${groupId}";
	def group = jsonParse(get(url));
	def projects=group.get("projects");
	println("Project size: ${projects.size()}")
	projects.each { project -> ret.add(project) }
	return ret
}

def getRegistryRepositories(def projectId) {
    def baseUrl = "https://gitlab.com/api/v4";
	def ret = [];
	def i = 1;
	while( true ) {
		String url = "${baseUrl}/projects/${projectId}/registry/repositories?per_page=100&page=${i}";
		def repos = jsonParse(get(url));
		if( repos.size() == 0 ) break
		repos.each { repo -> ret.add(repo) }
		i = i + 1;
	}
	return ret
}

def getTags(def projectId, def repositoryId) {
    def baseUrl = "https://gitlab.com/api/v4";
	def ret = [];
	def i = 1;
	while( true ) {
		String url = "${baseUrl}/projects/${projectId}/registry/repositories/${repositoryId}/tags?per_page=100&page=${i}";
		def tags = jsonParse(get(url));
		if( tags.size() == 0 ) break
		tags.each { tag -> ret.add(tag) }
		i = i + 1;
	}
	return ret
}
class Project {                       
    String id;
    String name;
    String path;
    String path_with_namespace;
	Project(id, name, path, path_with_namespace) {
        this.id = id
        this.name = name
        this.path = path
        this.path_with_namespace = path_with_namespace
    }
}

def parallelEntitiesClosure(entities, maxPool, closure) {
  def threadPool = Executors.newFixedThreadPool(maxPool)
   try {
    List<Future> futures = entities.collect {entity->
      threadPool.submit({->
      closure entity } as Callable);
    }
    // recommended to use following statement to ensure the execution of all tasks.
    futures.each{ it.get() }
  }finally {
    threadPool.shutdown()
  }
}

def projectPathList=[]

def collectProjects() {
    def groupId = "2653348"; //aangine
    def otherGroupId="7115574"; //aangine/backend-services
    def finalProjects = [];

    def projects = getProjects(groupId);
  	println("Number of Projects group ${groupId} : ${projects.size()}")
//	projects.collect{ project -> 
	parallelEntitiesClosure(projects, 5, { project -> 
//        println("Checking Project: ${project.get("name")}")
//		if (projectPathList.contins(project.path) ) {
			println("Adding Project: ${project.get("name")}")
			finalProjects.add(new Project(
			project.get("id"),
			project.get("name"),
			project.get("path"),
			project.get("path_with_namespace")
			));
//		}
	})
//	}
   
   def otherProjects = getProjects(otherGroupId);
  println("Number of Projects group ${otherGroupId} : ${otherProjects.size()}")
   
//	otherProjects.collect{ project -> 
	parallelEntitiesClosure(otherProjects, 5, { project -> 
//        println("Checking Project: ${project.get("name")}")
//		if (projectPathList.contins(project.path) ) {
			println("Adding Project: ${project.get("name")}")
			finalProjects.add(new Project(
			project.get("id"),
			project.get("name"),
			project.get("path"),
			project.get("path_with_namespace")
			));
//		}
	})
//    }
    //return projects
    return new JsonBuilder(finalProjects).toPrettyString();
}
def collectProjectRepositories(def projectId) {
	//println("Project: ${projectId}")

	def repositories = getRegistryRepositories(projectId);

	def finalRepositories = [];
	
	parallelEntitiesClosure(repositories, 5, { repository ->
		println("Project: ${projectId} - Repository: ${repository.get("name")}")
		ArrayList<HashMap> tags = getTags(projectId, repository.get("id"));

		//println("Tags: ${tags.size()}");
		if (tags.size() > 0) {
            finalRepositories.add(repository);
		}
	})
   
    //return projects
    return new JsonBuilder(finalRepositories).toPrettyString();
}
def collectProjectRepositoryTags(def projectId, def repositoryId) {
	//println("Project: ${projectId}")

	def finalTags = [];
	
	//println("Project: ${projectId} - Repository: ${repositoryId}")
	ArrayList<HashMap> tags = getTags(projectId, repositoryId);

	//println("Tags: ${tags.size()}");
	tags.each { tag -> finalTags.add(tag) }
   
    //return projects
    return new JsonBuilder(finalTags).toPrettyString();
}
def findProjectByPath(projects, path) {
	return projects.find{ it.path == path}
}
//return "<input value=\"${collectProjects();}\"/>
def projects = collectProjects();
def project = findProjectByPath(new groovy.json.JsonSlurper().parseText(projects), "aangine-ui")
return collectProjectRepositories(project.id)
///api/v4/projects/6525083/registry/repositories
//return collectProjectRepositoryTags("6525083", "1099021")