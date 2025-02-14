param location string = resourceGroup().location
param tags object = {}
param htpasswd string

// param containerEnvId string

param persistence bool = false
param imageName string = 'docker.io/arizephoenix/phoenix:sql-11'

param prefix string = 'phoenix'

param databaseName string = 'phoenix'
param databaseAdmin string = 'phoenixadmin'
param databasePassword string

module postgresServer 'database/flexibleserver.bicep' =
  if (persistence) {
    name: 'postgresql'
    scope: resourceGroup()
    params: {
      name: '${prefix}-postgresql'
      location: location
      tags: tags
      sku: {
        name: 'Standard_B1ms'
        tier: 'Burstable'
      }
      storage: {
        storageSizeGB: 32
      }
      version: '16'
      administratorLogin: databaseAdmin
      administratorLoginPassword: databasePassword
      allowAzureIPsFirewall: true
      databaseNames: [databaseName]
    }
  }

module logAnalyticsWorkspace 'monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: resourceGroup()
  params: {
    name: '${prefix}-loganalytics'
    location: location
    tags: tags
  }
}

module containerAppEnv 'host/container-app-env.bicep' = {
  name: 'container-env'
  scope: resourceGroup()
  params: {
    name: containerAppName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
  }
}

var containerAppName = '${prefix}-app'
module containerApp 'host/container-app.bicep' = {
  name: 'container'
  scope: resourceGroup()
  params: {
    name: containerAppName
    location: location
    tags: tags
    containerEnvId: containerAppEnv.outputs.id
    imageName: imageName
    htpasswd: htpasswd
    env: persistence
      ? [
          {
            name: 'PHOENIX_SQL_DATABASE_URL'
            value: 'postgresql://${postgresServer.outputs.fqdn}:5432/${databaseName}?user=${databaseAdmin}&password=${databasePassword}'
          }
        ]
      : []
  }
}

output SERVICE_APP_URI string = '${containerApp.outputs.uri}'
