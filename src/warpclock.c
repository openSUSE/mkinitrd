/*
 * Copyright (c) 2009 Werner Fink, 2009 SuSE LINUX Products GmbH, Germany.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Author:  Werner Fink <werner@suse.de>
 *
 * Based on a comment of the manual page settimeofday(2):
 *
 *   Under Linux there are some peculiar "warp clock" semantics associated
 *   with the settimeofday() system call if on the very first call (after
 *   booting) that has a non-NULL tz argument, the tv argument is NULL and
 *   the tz_minuteswest field is non-zero.  In such a case it is assumed
 *   that the CMOS clock is on local time, and that it has to be incremented
 *   by this amount to get UTC system time.  No doubt it is a bad idea to
 *   use this feature.
 *
 * From linux/kernel/time.c
 *
 *   The best thing to do is to keep the CMOS clock in universal time (UTC)
 *   as real UNIX machines always do it. This avoids all headaches about
 *   daylight saving times and warping kernel clocks.
 *
 *   In case for some reason the CMOS clock has not already been running
 *   in UTC, but in some local time: The first time we set the timezone,
 *   we will warp the clock so that it is ticking UTC time instead of
 *   local time. Presumably, if someone is setting the timezone then we
 *   are running in an environment where the programs understand about
 *   timezones. This should be done at boot time in the /etc/rc script,
 *   as soon as possible, so that the clock can be set right. Otherwise,
 *   various programs will get confused when the clock gets warped.
 *
 * As some systems, e.g. in a multi boot environment, have their RTC set to
 * local time we may depend on this feature.  For Windows[tm] users it
 * would be very interesting to read the comments from Markus Kuhn at
 * http://www.cl.cam.ac.uk/~mgk25/mswish/ut-rtc.html
 *
 * The kernel assumes that the RTC/HW clock is running in Universal time
 * and use at boot RTC to sets the kernel based System Time also in UTC.
 * this leads to problems on systems with RTC running in local time.
 * Therefore we have to warp the kernel based System Time back to run UTC.
 *
 * This program checks /etc/sysconfig/clock on a SuSE based Linux System
 * if the RTC/HW clock is running in local time. It also determine the
 * current offset from UTC in minutes west of the Universal time line.
 *
 * All user space programs assume that kernel based System Time is set to
 * UTC to be able to calculate their own time zone offset on that unique
 * base.  That is that e.g. date(1) use this System Time together with
 * /etc/localtime or the environment variable TZ to appoint the actual
 * local time (zone). To see this simply run
 *
 *	date --rfc-2822
 *
 * and check the time zone offset of the local time marked with `+'.
 */
#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

int main()
{
    FILE * conf;
    const char * err;
    struct tm *utc, *local;
    char buffer[LINE_MAX];
    struct timezone zone;
    time_t now, delta, gmtoff;
    struct stat st;
    int universal = 0;
    int count, adj;

    err = "warpclock: /etc/localtime";
    if (stat("/etc/localtime", &st) < 0)
	goto err;
    clearenv();			/* Ignore e.g. TZ */
    tzset();			/* Open /etc/localtime */

    memset(&zone, 0, sizeof(struct timezone));

    adj = 1;
    err = "warpclock: /etc/adjtime";
    if ((conf = fopen("/etc/adjtime", "r")) == (FILE *)0) {
	if (errno != ENOENT)
	    goto err;
	adj = 0;
	err = "warpclock: /etc/sysconfig/clock";
	if ((conf = fopen("/etc/sysconfig/clock", "r")) == (FILE *)0)
	    goto err;
    }
    while ((fgets(&buffer[0], sizeof(buffer), conf))) {
	const char * ptr = &buffer[0];
	while (isblank(*ptr))
	    ptr++;
	if (*ptr == '#')
	    continue;
	if (*ptr == '\n')
	    continue;
	if (adj) {
	    char *end;
	    if ((end = strrchr(ptr, '\n')))
		*end = '\0';
	    if (strcmp("UTC", ptr) == 0) {
		universal = 1;
		break;
	    }
	} else if (strncmp("HWCLOCK=", ptr, 8) == 0) {
	    universal = !strstr(ptr, "-l");
	    break;
	}
    }
    fclose(conf);

    if (universal)
	goto out;

    count = 300;
    errno = EFAULT;
    err = "warpclock: system time not synched";
    while ((now = time(NULL)) < 60 * 60) {
	if ((now == (time_t)-1) || (count-- <= 0))
	    goto err;
	usleep(10000);		/* Wait on the System Time */
    }

    errno = EINVAL;
    err = "warpclock: localtime()";
    if ((local = localtime(&now)) == (struct tm *)0)
	goto err;
    gmtoff = (time_t)local->tm_gmtoff;

    errno = EINVAL;
    err = "warpclock: gmtime()";
    if ((utc = gmtime(&now)) == (struct tm *)0)
	goto err;
    delta = mktime(utc) - now;

#if 0
    /*
     * As long as we have no chance to use tm_isdst from the RTC
     * aka HW CMOS clock, we are not able to determine if the
     *   Dayligth Saving Time (DST)
     * mode has changed between to system boots. If the Linux
     * kernel would use and export the DST flag bit of the RTC
     * it could be used to check if DST mode has changed and we
     * could determine the offset required for the correct
     * System Time and clear or set the DST flag bit of the RTC.
     */

    if (rtc->tm_isdst != local->tm_isdst) {	/* DST <-> Normal Time */
	if (!local->tm_isdst) {
	    const time_t dstoff = gmtoff + delta;
	    gmtoff += dstoff;		/* DST -> Normal Time */
	} else {
	    const time_t dstoff = gmtoff + delta;
	    gmtoff -= dstoff;		/* DST <- Normal Time */
	}
    }
#endif
    if (gmtoff == 0)
	goto out;		/* Nothing todo */
    zone.tz_minuteswest = -(typeof(zone.tz_minuteswest))(gmtoff/60L);

				/* Warp System Time back to UTC */
    err = "warpclock: warp system clock";
    if (syscall(SYS_settimeofday, (struct timeval *)0, &zone) < 0)
	goto err;
				/* Reset time zone back to zero */
out:
    return 0;
err:
    fprintf(stderr, "%s: %s\n", err, strerror(errno));
    return 1;
}
