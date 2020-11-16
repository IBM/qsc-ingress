FROM nginx:1.19.4-alpine
RUN apk update  \
	&& apk upgrade  \
	&& apk add bash
COPY entrypoint.sh .
COPY index.html /usr/share/nginx/html/index.html
ENTRYPOINT ["./entrypoint.sh"]