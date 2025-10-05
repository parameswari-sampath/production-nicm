FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/nginx.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80 and 443
EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
