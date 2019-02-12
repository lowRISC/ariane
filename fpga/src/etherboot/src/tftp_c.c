/**
 * tftp_c.c - tftp client
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
/**
 * utility.h - header file which contains common function of tftp_c.c and tftp_s.c
 */
#include "eth.h"

#define MYPORT "4950" // port to be opened on server
#define SERVERPORT "4950" // the port users will be connecting to
#define MAXBUFLEN 550 // get sockaddr, IPv4 or IPv6:
#define MAX_READ_LEN 512 // maximum data size that can be sent on one packet
#define MAX_FILENAME_LEN 100 // maximum length of file name supported
#define MAX_PACKETS 99 // maximum number of file packets
#define MAX_TRIES 3 // maximum number of tries if packet times out
#define TIME_OUT 5 // in seconds


// converts block number to length-2 string
void s_to_i(char *f, int n){
	if(n==0){
		f[0] = '0', f[1] = '0', f[2] = '\0';
	} else if(n%10 > 0 && n/10 == 0){
		char c = n+'0';
		f[0] = '0', f[1] = c, f[2] = '\0';
	} else if(n%100 > 0 && n/100 == 0){
		char c2 = (n%10)+'0';
		char c1 = (n/10)+'0';
		f[0] = c1, f[1] = c2, f[2] = '\0';
	} else {
		f[0] = '9', f[1] = '9', f[2] = '\0';
	}
}

// makes RRQ packet
char* make_rrq(char *filename){
	char *packet;
        int len = 2+strlen(filename);
	packet = mysbrk(len);
	memset(packet, 0, len);
	strcat(packet, "01");//opcode
	strcat(packet, filename);
	return packet;
}

// makes WRQ packet
char* make_wrq(char *filename){
	char *packet;
        int len = 2+strlen(filename);
	packet = mysbrk(len);
	memset(packet, 0, len);
	strcat(packet, "02");//opcode
	strcat(packet, filename);
	return packet;
}

// makes data packet
char* make_data_pack(int block, char *data){
	char *packet;
	char temp[3];
        int len = 4+strlen(data);
	s_to_i(temp, block);
	packet = mysbrk(len);
	memset(packet, 0, len);
	strcat(packet, "03");//opcode
	strcat(packet, temp);
	strcat(packet, data);
	return packet;
}

// makes ACK packet
char* make_ack(char* block){
	char *packet;
        int len = 2+strlen(block);
	packet = mysbrk(len);
	memset(packet, 0, len);
	strcat(packet, "04");//opcode
	strcat(packet, block);
	return packet;
}

// makes ERR packet
char* make_err(char *errcode, char* errmsg){
	char *packet;
        int len = 4+strlen(errmsg);
	packet = mysbrk(len);
	memset(packet, 0, len);
	strcat(packet, "05");//opcode
	strcat(packet, errcode);
	strcat(packet, errmsg);
	return packet;
}

const char *peer(void) {
  return "localhost";
}

int poll(int sockfd, char *buf, int max) {
  return 0;
}

int sendto(int sockfd, char *buf, int max) {
  return 0;
}

void file_open_write(const char *nam)
{

}

void packet_write(char *buf, int siz)
{

}

void file_close(void)
{

}

// TIMEOUT DISABLED IN THIS VERSION
int check_timeout(int sockfd, char *buf) {
	return poll(sockfd, buf, MAXBUFLEN-1);
}

int tftp_main(int sockfd, const char *direction, char *server, char *file){

        //	struct addrinfo *p;
	int numbytes;
	char buf[MAXBUFLEN];
		
	//===========CONFIGURATION OF CLIENT - ENDS===========


	//===========MAIN IMPLEMENTATION - STARTS===========
	if(strcmp(direction, "GET") == 0 || strcmp(direction, "get") == 0){ //GET DATA FROM SERVER
		//SENDING RRQ
		char *message = make_rrq(file);
		char last_recv_message[MAXBUFLEN];strcpy(last_recv_message, "");
		char last_sent_ack[10];strcpy(last_sent_ack, message);
		if((numbytes = sendto(sockfd, message, strlen(message))) == -1){
			perror("CLIENT: sendto");
			return(1);
		}
		printf("CLIENT: sent %d bytes to %s\n", numbytes, server);

		char filename[MAX_FILENAME_LEN];
		strcpy(filename, file);
		strcat(filename, "_client");

		file_open_write(filename);

		//RECEIVING ACTUAL FILE
		int c_written;
		do{
			//RECEIVING FILE - PACKET DATA
			if ((numbytes = poll(sockfd, buf, MAXBUFLEN-1)) == -1) {
				perror("CLIENT: recvfrom");
				return(1);
			}
			printf("CLIENT: got packet from %s\n", peer());
			printf("CLIENT: packet is %d bytes long\n", numbytes);
			buf[numbytes] = '\0';
			printf("CLIENT: packet contains \"%s\"\n", buf);

			//CHECKING IF ERROR PACKET
			if(buf[0]=='0' && buf[1]=='5'){
				printf("CLIENT: got error packet: %s\n", buf);
				return(1);
			}

			//SENDING LAST ACK AGAIN - AS IT WAS NOT REACHED
			if(strcmp(buf, last_recv_message) == 0){
				sendto(sockfd, last_sent_ack, strlen(last_sent_ack));
				continue;
			}

			//WRITING FILE - PACKET DATA
			c_written = strlen(buf+4);
			packet_write(buf+4, c_written);
			strcpy(last_recv_message, buf);

			//SENDING ACKNOWLEDGEMENT - PACKET DATA
			char block[3];
			strncpy(block, buf+2, 2);
			block[2] = '\0';
			char *t_msg = make_ack(block);
			if((numbytes = sendto(sockfd, t_msg, strlen(t_msg))) == -1){
				perror("CLIENT ACK: sendto");
				return(1);
			}
			printf("CLIENT: sent %d bytes\n", numbytes);
			strcpy(last_sent_ack, t_msg);
		} while(c_written == MAX_READ_LEN);
		printf("NEW FILE: %s SUCCESSFULLY MADE\n", filename);
                file_close();
	} else if(strcmp(direction, "PUT") == 0 || strcmp(direction, "put") == 0){	//WRITE DATA TO SERVER	
#if 0
                //SENDING WRQ
		char *message = make_wrq(file);
		char *last_message;
		if((numbytes = sendto(sockfd, message, strlen(message))) == -1){
			perror("CLIENT: sendto");
			exit(1);
		}
		printf("CLIENT: sent %d bytes to %s\n", numbytes, server);
		last_message = message;

		//WAITING FOR ACKNOWLEDGEMENT - WRQ
		int times;
		for(times=0;times<=MAX_TRIES;++times){
			if(times == MAX_TRIES){// reached max no. of tries
				printf("CLIENT: MAX NUMBER OF TRIES REACHED\n");
				exit(1);
			}

			// checking if timeout has occurred or not
			numbytes = check_timeout(sockfd, buf);
			if(numbytes == -1){//error
				perror("CLIENT: recvfrom");
				exit(1);
			} else if(numbytes == -2){//timeout
				printf("CLIENT: try no. %d\n", times+1);
				int temp_bytes;
				if((temp_bytes = sendto(sockfd, last_message, strlen(last_message))) == -1){
					perror("CLIENT ACK: sendto");
					exit(1);
				}
				printf("CLIENT: sent %d bytes AGAIN\n", temp_bytes);
				continue;
			} else { //valid
				break;
			}
		}
		printf("CLIENT: got packet from %s\n", peer());
		printf("CLIENT: packet is %d bytes long\n", numbytes);
		buf[numbytes] = '\0';
		printf("CLIENT: packet contains \"%s\"\n", buf);

		if(buf[0]=='0' && buf[1]=='4'){
			FILE *fp = fopen(file, "rb");
			if(fp == NULL || access(file, F_OK) == -1){
				printf("CLIENT: file %s does not exist\n", file);
				exit(1);
			}

			//calculating of size of file
			int block = 1;
			fseek(fp, 0, SEEK_END);
			int total = ftell(fp);
			fseek(fp, 0, SEEK_SET);
			int remaining = total;
			if(remaining == 0)
				++remaining;
			else if(remaining%MAX_READ_LEN == 0)
				--remaining;

			while(remaining>0){
				//READING FILE - DATA PACKET
				char temp[MAX_READ_LEN+5];
				if(remaining>MAX_READ_LEN){
					fread(temp, MAX_READ_LEN, sizeof(char), fp);
					temp[MAX_READ_LEN] = '\0';
					remaining -= (MAX_READ_LEN);
				} else {
					fread(temp, remaining, sizeof(char), fp);
					temp[remaining] = '\0';
					remaining = 0;
				}

				//SENDING FILE - DATA PACKET
				char *t_msg = make_data_pack(block, temp);
				if((numbytes = sendto(sockfd, t_msg, strlen(t_msg))) == -1){
					perror("CLIENT: sendto");
					exit(1);
				}
				printf("CLIENT: sent %d bytes to %s\n", numbytes, server);
				last_message = t_msg;

				//WAITING FOR ACKNOWLEDGEMENT - DATA PACKET
				int times;
				for(times=0;times<=MAX_TRIES;++times){
					if(times == MAX_TRIES){
						printf("CLIENT: MAX NUMBER OF TRIES REACHED\n");
						exit(1);
					}

					numbytes = check_timeout(sockfd, buf);
					if(numbytes == -1){//error
						perror("CLIENT: recvfrom");
						exit(1);
					} else if(numbytes == -2){//timeout
						printf("CLIENT: try no. %d\n", times+1);
						int temp_bytes;
						if((temp_bytes = sendto(sockfd, last_message, strlen(last_message))) == -1){
							perror("CLIENT ACK: sendto");
							exit(1);
						}
						printf("CLIENT: sent %d bytes AGAIN\n", temp_bytes);
						continue;
					} else { //valid
						break;
					}
				}
				printf("CLIENT: got packet from %s\n", peer());
				printf("CLIENT: packet is %d bytes long\n", numbytes);
				buf[numbytes] = '\0';
				printf("CLIENT: packet contains \"%s\"\n", buf);

				if(buf[0]=='0' && buf[1]=='5'){//if error packet received
					printf("CLIENT: got error packet: %s\n", buf);
					exit(1);
				}
				
				++block;
				if(block>MAX_PACKETS)
					block = 1;
			}
			
			fclose(fp);
		} else {//some bad packed received
			printf("CLIENT ACK: expecting but got: %s\n", buf);
			exit(1);
		}
#endif
	} else { //INVALID REQUEST
		printf("USAGE: tftp_c GET/PUT server filename\n");
		return (1);
	}
	//===========MAIN IMPLEMENTATION - ENDS===========

	return 0;
}
