FROM debian:stretch
MAINTAINER František Dvořák <valtri@civ.zcu.cz>

ENV v 3.5.1

EXPOSE 8009 8080

WORKDIR /root

# graphviz - for GUI features
# xlmstaret - for docker image scripts
# tomcat8 additional packages (to prevent warnings), native package
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    graphviz \
    libmysql-java \
    mc \
    openjdk-8-jdk \
    tomcat8 libservlet3.1-java libcommons-dbcp-java libcommons-pool-java libtcnative-1 \
    wget \
    xmlstarlet \
&& rm -rf /var/lib/apt/lists/*

# mc (cosmetics)
RUN mkdir -p ~/.config/mc/ \
&& echo 'ENTRY "/var/lib/tomcat8/webapps/midpoint/WEB-INF" URL "/var/lib/tomcat8/webapps/midpoint/WEB-INF"' >> ~/.config/mc/hotlist \
&& echo 'ENTRY "/var/log/tomcat8" URL "/var/log/tomcat8"' >> ~/.config/mc/hotlist \
&& echo 'ENTRY "/var/opt/midpoint" URL "/var/opt/midpoint"' >> ~/.config/mc/hotlist \
&& ln -s /usr/lib/mc/mc.csh /etc/profile.d/ \
&& ln -s /usr/lib/mc/mc.sh /etc/profile.d/

# tomcat
RUN echo 'JAVA_OPTS="${JAVA_OPTS} -Xms256m -Xmx1024m -Xss1m -Dmidpoint.home=/var/opt/midpoint -Djavax.net.ssl.trustStore=/var/opt/midpoint/keystore.jceks -Djavax.net.ssl.trustStoreType=jceks"' >> /etc/default/tomcat8 \
&& sed -i '/Service name="Catalina".*/a \\n    <Connector port="8009" protocol="AJP/1.3"/>' /etc/tomcat8/server.xml
RUN mkdir /var/opt/midpoint
RUN chown tomcat8:tomcat8 /var/opt/midpoint
RUN service tomcat8 stop

# midpoint
RUN wget -nv https://evolveum.com/downloads/midpoint/${v}/midpoint-${v}-dist.tar.bz2 \
&& tar xjf midpoint-${v}-dist.tar.bz2 -C /opt \
&& rm -f midpoint-${v}-dist.tar.bz2
RUN sed -e "s,^\(BASEDIR\).*,\1=\"/opt/midpoint-${v}\"," /opt/midpoint-${v}/bin/repo-ninja > /usr/local/bin/repo-ninja \
&& chmod +x /usr/local/bin/repo-ninja

# deployment
# (tomcat8 startup is OK, but returns non-zero code)
RUN service tomcat8 start || : \
&& cp -vp /opt/midpoint-${v}/war/midpoint.war /var/lib/tomcat8/webapps/ \
&& while ! test -f /var/opt/midpoint/config.xml; do sleep 0.5; done \
&& sleep 60
RUN ln -s /usr/share/java/mysql-connector-java.jar /var/lib/tomcat8/lib/
RUN wget -nv -P /var/opt/midpoint/icf-connectors/ http://nexus.evolveum.com/nexus/content/repositories/openicf-releases/org/forgerock/openicf/connectors/scriptedsql-connector/1.1.2.0.em3/scriptedsql-connector-1.1.2.0.em3.jar

COPY docker-entry.sh /
CMD /docker-entry.sh /bin/bash -l
