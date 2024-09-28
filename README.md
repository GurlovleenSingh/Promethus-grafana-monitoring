# Promethus-grafana-monitoring
EKS cluster monitoring with Promethus Grafana 



Accessing Grafana///////////////////////////////////////
After Grafana is installed, you can access its dashboard with the following command:

kubectl port-forward -n monitoring service/grafana 3000:80

This command allows you to access Grafana locally on http://localhost:3000. The default login credentials are usually admin/admin, and you'll be prompted to change the password upon first login.
