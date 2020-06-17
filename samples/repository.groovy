import groovy.json.*; 
import org.json.JSONObject; 
import groovy.json.JsonSlurper;
import groovy.json.JsonBuilder;
def get(def url) {
    def personalAccessToken = "CKxDxsG9yU-gGD5wCNL1";  //cs-infra
    def connection = new URL(url).openConnection() as HttpURLConnection;
    connection.setRequestMethod("GET");
    connection.setRequestProperty("PRIVATE-TOKEN", personalAccessToken);
    //connection.setInstanceFollowRedirects(true);
    //connection.setReadTimeout(60000);
    //connection.setConnectTimeout(60000);
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
	def i = 1;
	while( true ) {
		String url = "${baseUrl}/groups/${groupId}?per_page=100&page=${i}";
		def group = jsonParse(get(url));
		def projects=group.get("projects");
		println("Project size: ${projects.size()}")
		if( projects.size() == 0 ) break
		projects.each { project -> ret.add(project) }
		i = i + 1;
	}
	return ret
}

def getRegistryRepositories(def projectId) {
    def baseUrl = "https://gitlab.com/api/v4";
	def ret = [];
	def i = 1;
	while( true ) {
		String url = "${baseUrl}/projects/${projectId}/registry/repositories?per_page=100&page=${i}";
		def repos = jsonParse(get(url));
		println("Project: ${projectId} repos size: ${repos.size()}")
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
		println("Project: ${projectId}, Repo: ${repositoryId} tags size: ${tags.size()}")
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
def collectProjects() {
    def groupId = "2653348"; //aangine
    def otherGroupId="7115574"; //aangine/backend-services
    def finalProjects = [];

    def projects = getProjects(groupId);
 
    projects.each { project ->
        //println("Project: ${project.get("name")}")

        def repositories = getRegistryRepositories(project.get("id"));

        def finalRepositories = [];
        def state = 0;
        repositories.each { repository ->
            //println("Project: ${project.get("name")} - Repository: ${repository.get("name")}")
            ArrayList<HashMap> tags = getTags(project.get("id"), repository.get("id"));

            //println("Tags: ${tags}");
            if (state == 0 && tags.size() > 0) {
				finalProjects.add(new Project(
				project.id,
				project.name,
				project.path,
				project.path_with_namespace,
				));
				state = 1;
            }
        }
    }
   
   def otherProjects = getProjects(otherGroupId);
   
   otherProjects.each { project ->
        //println("Project: ${project.get("name")}")

        def repositories = getRegistryRepositories(project.get("id"));

        def finalRepositories = [];
        
        def state = 0;
        repositories.each { repository ->
            //println("Project: ${project.get("name")} - Repository: ${repository.get("name")}")
          ArrayList<HashMap> tags = getTags(project.get("id"), repository.get("id"));

            //println("Tags: ${tags}");
            if (state == 0 && tags.size() > 0) {
				finalProjects.add(new Project(
				project.id,
				project.name,
				project.path,
				project.path_with_namespace,
				));
				state = 1;
            }
        }
    }
    //return projects
    return new JsonBuilder(finalProjects).toPrettyString();
}
def collectProjectRepositories(def projectId) {
	//println("Project: ${projectId}")

	def repositories = getRegistryRepositories(projectId);

	def finalRepositories = [];
	
	repositories.each { repository ->
		//println("Project: ${projectId} - Repository: ${repository.get("name")}")
		ArrayList<HashMap> tags = getTags(projectId, repository.get("id"));

		//println("Tags: ${tags.size()}");
		if (tags.size() > 0) {
            finalRepositories.add(repository);
		}
	}
   
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
def collectAll() {
    def groupId = "2653348"; //aangine
    def otherGroupId="7115574"; //aangine/backend-services
    def finalProjects = [];

    def projects = getProjects(groupId);
 
    projects.each { project ->
        //println("Project: ${project.get("name")}");

        def repositories = getRegistryRepositories(project.get("id"));

        def finalRepositories = [];
        
        repositories.each { repository ->
            println("Project: ${project.get("name")} - Repository: ${repository.get("name")}");
            ArrayList<HashMap> tags = getTags(project.get("id"), repository.get("id"));

            println("Tags: ${tags}");
            if (tags.size() > 0) {
                finalRepositories.add(repository);
                repository.put("tags", tags);
            }
        }
        if (finalRepositories.size() > 0) {
            println("Adding Project: ${project.get("name")} ...");
            project.put("repositories", finalRepositories);
            finalProjects.add(project);
        }
    }
   
   def otherProjects = getProjects(otherGroupId);
   
   otherProjects.each { project ->
        println("Project: ${project.get("name")}");

        def repositories = getRegistryRepositories(project.get("id"));

        def finalRepositories = [];
        
        repositories.each { repository ->
            println("Project: ${project.get("name")} - Repository: ${repository.get("name")}");
          ArrayList<HashMap> tags = getTags(project.get("id"), repository.get("id"));

            println("Tags: ${tags}");
            if (tags.size() > 0) {
                finalRepositories.add(repository);
                repository.put("tags", tags);
            }
        }
        if (finalRepositories.size() > 0) {
            println("Adding Project: ${project.get("name")} ...");
            project.put("repositories", finalRepositories);
            finalProjects.add(project);
        }
    }
    //return projects
    return new JsonBuilder(finalProjects).toPrettyString();
}
//return collectProjects();
//return collectProjectRepositories("6525083")
///api/v4/projects/6525083/registry/repositories
return collectProjectRepositoryTags("6525083", "1099021")