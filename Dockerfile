# Use an official Python image as the base
FROM python:3.10

# Set the working directory in the container
WORKDIR /app

# Copy files from the parent folder into the container's /app directory
COPY . /app

# Ensure we have all necessary repositories and install required packages
RUN apt-get update && apt-get install -y python3.10 python3-venv python3-dev gcc libssl-dev

# Make sure the wait-for-it script is executable
RUN chmod +x wait-for-it.sh

# Create and activate the virtual environment
RUN python3.10 -m venv venv

# Activate the virtual environment and install the dependencies
RUN /bin/bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r ./requirements.txt"

# Expose the port your application runs on
EXPOSE 8080

# Command to run the application after ensuring the DB is ready
#CMD ["./wait-for-it.sh", "db:3306", "--", "/bin/bash", "-c", "source venv/bin/activate && gunicorn --workers 4 --bind 0.0.0.0:8080 --access-logfile - --error-logfile - app:app"]
# Command to run the application after ensuring the DB is ready
CMD ["/bin/bash", "-c", "source venv/bin/activate && gunicorn --workers 4 --bind 0.0.0.0:8080 --access-logfile - --error-logfile - app:app"]
