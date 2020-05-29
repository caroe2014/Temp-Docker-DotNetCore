#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

 

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-buster-slim AS base

WORKDIR /app

RUN apt-get update -y && apt-get install git -y && git clone https://github.com/mapbox/tippecanoe.git
RUN apt-get install build-essential libsqlite3-dev zlib1g-dev -y
RUN cd tippecanoe && make -j && make install
RUN apt-get install vim-tiny -y
# think about how to slim the image down.  a lot of this stuff is just needed to git and build the bits.
# maybe we can create our own dotnet core / python / tippecanoe image in the future...

 

FROM mcr.microsoft.com/dotnet/core/sdk:3.1-buster AS build
WORKDIR /src
COPY ["VectorTileCacheService/VectorTileCacheService.csproj", "VectorTileCacheService/"]
RUN dotnet restore "VectorTileCacheService/VectorTileCacheService.csproj"
COPY . .
WORKDIR "/src/VectorTileCacheService"

# =================   SSH  BEGIN =================================
ENV SSH_PASSWD "root:Docker!"

RUN apt-get update \
	&& apt-get install -y apt-utils \
          unzip \
          openssh-server \
          vim \
          curl \
          wget \
          tcptraceroute \
    && echo "$SSH_PASSWD" | chpasswd 

COPY sshd_config /etc/ssh/

#   ==================== SSH END   ====================================

# For development using Debug, change to release with going to prod
RUN dotnet build "VectorTileCacheService.csproj" -c Debug -o /app/build

FROM build AS publish
# For development using Debug, change to release with going to prod
RUN dotnet publish "VectorTileCacheService.csproj" -c Debug -o /app/publish

# ==================  SSH Permissions Begin  ==========================
RUN chmod u+x /usr/local/bin/init_container.sh \
     && chmod 755 /opt  \
     && echo "$SSH_PASSWD" | chpasswd \
     && echo "cd /home" >> /etc/bash.bashrc
#
# This next section is to add ssh into the log
# And add Sym link of the log to /home/LogFiles
#RUN mkdir -p /home/LogFiles \
#     && ln -s /home/LogFiles /opt/coldfusion/cfusion/logs \
#     && chmod 777 /home/LogFiles \
#     && echo "$SSH_PASSWD" | chpasswd \
#     && echo "cd /home" >> /etc/bash.bashrc

# ======================= SSH Permission End ===========================
ENV SSH_PORT 2222 
EXPOSE 80 2222

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "VectorTileCacheService.dll"]