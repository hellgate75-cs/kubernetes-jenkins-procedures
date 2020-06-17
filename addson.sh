function variableType() {
	if [[ "$1" =~ ^[+-]?[0-9]+$ ]]; then
	  echo "number"
	elif [[ $1 =~ ^[+-]?[0-9]*\.[0-9]+$ ]]; then
	  echo "float"
	elif [[ $1 =~ [0-9] ]]; then
	  echo "mixed"
	else
	  echo "alphanumeric"
	fi
}

function translateServiceToTemplate() {
	if [ "$1" = "aangine-ui" ]; then
		echo "AANGINE_UI_BRANCH:AANGINE_UI_VERSION:AANGINE_UI_ENABLED"
	elif [ "$1" = "aangine-ui-scenario-comparison" ]; then
		echo ":"
	elif [ "$1" = "auth-service" ]; then
		echo "AUTH_BRANCH:AUTH_VERSION:AUTH_ENABLED"
	elif [ "$1" = "businessunit-service-businessunit" ]; then
		echo "BUSINESS_UNIT_BRANCH:BUSINESS_UNIT_VERSION:BUSINESS_UNIT_ENABLED"
	elif [ "$1" = "calendar-service-calendar" ]; then
		echo "CALENDAR_BRANCH:CALENDAR_VERSION:CALENDAR_ENABLED"
	elif [ "$1" = "capacity-service-capacity" ]; then
		echo "CAPACITY_BRANCH:CAPACITY_VERSION:CAPACITY_ENABLED"
	elif [ "$1" = "characteristic-service" ]; then
		echo "CHARACTERISTIC_BRANCH:CHARACTERISTIC_VERSION:CHARACTERISTIC_ENABLED"
	elif [ "$1" = "composition-service" ]; then
		echo "COMPOSITION_BRANCH:COMPOSITION_VERSION:COMPOSITION_ENABLED"
	elif [ "$1" = "excel-integration-service" ]; then
		echo "EXCEL_INTEGRATION_BRANCH:EXCEL_INTEGRATION_VERSION:EXCEL_INTEGRATION_ENABLED"
	elif [ "$1" = "integration-persistence-service" ]; then
		echo "INTEGRATION_PERSISTENCE_BRANCH:INTEGRATION_PERSISTENCE_VERSION:INTEGRATION_PERSISTENCE_ENABLED"
	elif [ "$1" = "methodology-service-methodology" ]; then
		echo "METHODOLOGY_BRANCH:METHODOLOGY_VERSION:METHODOLOGY_ENABLED"
	elif [ "$1" = "platform-service-consul" ]; then
		echo ":"
	elif [ "$1" = "platform-service-mongo" ]; then
		echo ":"
	elif [ "$1" = "platform-service-network" ]; then
		echo ":"
	elif [ "$1" = "platform-service-nginx" ]; then
		echo ":"
	elif [ "$1" = "portfolio-item-service" ]; then
		echo "PORTFOLIO_ITEM_BRANCH:PORTFOLIO_ITEM_VERSION:PORTFOLIO_ITEM_ENABLED"
#	elif [ "$1" = "ppm-integration-agent" ]; then
#		echo "PPM_INTEGRATION_BRANCH:PPM_INTEGRATION_VERSION:PPM_INTEGRATION_ENABLED"
#	elif [ "$1" = "ppm-integration-service" ]; then
#		echo "PPM_INTEGRATION_SERVICE_BRANCH:PPM_INTEGRATION_SERVICE_VERSION:PPM_INTEGRATION_SERVICE_ENABLED"
	elif [ "$1" = "simulation-service-simulation" ]; then
		echo "SIMULATION_BRANCH:SIMULATION_VERSION:SIMULATION_ENABLED"
	else
		echo ":"
	fi
}

function getServiceList() {
	echo "aangine-ui"
	echo "auth-service"
	echo "businessunit-service-businessunit"
	echo "calendar-service-calendar"
	echo "capacity-service-capacity"
	echo "characteristic-service"
	echo "composition-service"
	echo "excel-integration-service"
	echo "integration-persistence-service"
	echo "methodology-service-methodology"
	echo "portfolio-item-service"
#	echo "ppm-integration-agent"
#	echo "ppm-integration-service"
	echo "simulation-service-simulation"
}
