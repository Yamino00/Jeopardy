# ---- Stage 1: build con Maven ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Prima solo il pom: il layer delle dipendenze resta in cache
# finche' il pom non cambia
COPY pom.xml .
RUN mvn -q -B dependency:go-offline

COPY src ./src
RUN mvn -q -B package -DskipTests

# ---- Stage 2: archivio CDS ----
# In produzione il servizio scende a zero repliche quando nessuno gioca, quindi
# ogni partita comincia con un avvio a freddo della JVM su mezza vCPU: e' la
# prima cosa che l'host vede aprendo l'app. AppCDS mette in un archivio le
# classi gia' lette e verificate, cosi' all'avvio vero non si rifa' quel lavoro.
#
# Serve uno stage a parte perche' l'archivio si costruisce facendo partire
# davvero l'applicazione una volta. Le proprieta' qui sotto servono tutte a
# far arrivare il contesto Spring fino in fondo senza un database: durante
# l'addestramento non c'e' niente a cui connettersi, e senza neutralizzare
# Flyway, la validazione dello schema e la lettura dei metadati JDBC l'avvio
# si fermerebbe prima di avere caricato le classi che ci interessano.
#
# L'immagine e' la stessa dello stage di runtime, e non e' un dettaglio: un
# archivio dinamico e' legato all'archivio di base della JVM che l'ha prodotto.
# Costruendolo su `jdk-alpine` e usandolo su `jre-alpine` la verifica del
# checksum fallisce, e con -Xshare:auto la macchina virtuale lo scarta senza
# dire niente: si paga il peso dell'archivio e non si guadagna un millisecondo.
# (Successo verificato: la build fallisce se l'archivio non e' utilizzabile.)
FROM eclipse-temurin:21-jre-alpine AS cds
WORKDIR /build
COPY --from=build /workspace/target/*.jar app.jar

# Boot 3.3 sa estrarre il jar in una forma che la JVM puo' indicizzare: dentro
# un fat jar le classi non sono sul classpath normale, e senza estrarle
# l'archivio verrebbe quasi vuoto.
RUN java -Djarmode=tools -jar app.jar extract --destination app

RUN cd app && \
    java -XX:ArchiveClassesAtExit=app.jsa \
         -Dspring.context.exit=onRefresh \
         -Dspring.datasource.url=jdbc:postgresql://cds.invalid:5432/cds \
         -Dspring.datasource.username=cds \
         -Dspring.datasource.password=cds \
         -Dspring.datasource.hikari.initialization-fail-timeout=-1 \
         -Dspring.flyway.enabled=false \
         -Dspring.jpa.hibernate.ddl-auto=none \
         -Dspring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect \
         -Dspring.jpa.properties.hibernate.boot.allow_jdbc_metadata_access=false \
         -jar app.jar

# Prova del nove: -Xshare:on fallisce l'avvio se l'archivio non e' utilizzabile,
# invece di ignorarlo in silenzio come farebbe -Xshare:auto. Se questo passo
# rompe la build, l'archivio non serviva a niente e va indagato qui, non in
# produzione dove nessuno se ne accorgerebbe.
RUN cd app && \
    java -XX:SharedArchiveFile=app.jsa -Xshare:on \
         -Dspring.context.exit=onRefresh \
         -Dspring.datasource.url=jdbc:postgresql://cds.invalid:5432/cds \
         -Dspring.datasource.username=cds \
         -Dspring.datasource.password=cds \
         -Dspring.datasource.hikari.initialization-fail-timeout=-1 \
         -Dspring.flyway.enabled=false \
         -Dspring.jpa.hibernate.ddl-auto=none \
         -Dspring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect \
         -Dspring.jpa.properties.hibernate.boot.allow_jdbc_metadata_access=false \
         -jar app.jar

# ---- Stage 3: runtime su JRE slim ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Utente non-root
RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=cds --chown=app:app /build/app ./

# MaxRAMPercentage: il container ha un limite di memoria basso e la JVM deve
# stare dentro quello, non dentro la memoria dell'host.
# SerialGC: su mezza vCPU i collector concorrenti costano piu' di quanto
# rendano, e partono piu' lentamente.
# SharedArchiveFile con -Xshare:auto: se l'archivio manca o e' stato prodotto
# da una JVM diversa, la macchina virtuale lo ignora e parte comunque.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+UseSerialGC -XX:SharedArchiveFile=app.jsa -Xshare:auto"

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
