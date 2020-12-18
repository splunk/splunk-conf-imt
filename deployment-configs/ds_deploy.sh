#RUN ON DEPLOYMENT SERVER

#pull down latest configs
git clone https://github.com/splunk/splunk-conf-imt.git

#enter config dir
cd splunk-conf-imt

#copy GDI inputs apps to DS deployment apps folder to prep for delivery to hosts via UF phone home
cp -R gdi-configs/deployment-server/deployment-apps/inputs/* /opt/splunk/etc/deployment-apps/.
cp -R gdi-configs/deployment-server/deployment-apps/tas/* /opt/splunk/etc/deployment-apps/.