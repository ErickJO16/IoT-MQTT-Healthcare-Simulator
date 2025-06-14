# Use an official lightweight Linux image
FROM debian:latest

# Set the working directory
WORKDIR /moxie

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    nmap \
    sudo \
    mosquitto-clients \
    net-tools \
    vim \
    iputils-ping \    
    && rm -rf /var/lib/apt/lists/*

# Clone the Moxie repository
#RUN git clone https://github.com/aravind0x7/Moxie.git .

# Copy all project files into the container
COPY . .

# Make the script executable
RUN chmod +x moxie.sh

# Set the default command to display help
#CMD ["./moxie.sh", "-h"]
