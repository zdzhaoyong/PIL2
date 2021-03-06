
#ifndef PIL_Process_UNIX_INCLUDED
#define PIL_Process_UNIX_INCLUDED

#include <unistd.h>
#include <vector>
#include <map>

#include "../Environment.h"
#include "RefCountedObject.h"


namespace pi {


class Pipe;


class PIL_API ProcessHandleImpl: public RefCountedObject
{
public:
	ProcessHandleImpl(pid_t pid);
	~ProcessHandleImpl();
	
	pid_t id() const;
	int wait() const;
	
private:
	pid_t _pid;
};


class PIL_API ProcessImpl
{
public:
	typedef pid_t PIDImpl;
	typedef std::vector<std::string> ArgsImpl;
	typedef std::map<std::string, std::string> EnvImpl;
	
	static PIDImpl idImpl();
	static void timesImpl(long& userTime, long& kernelTime);
	static ProcessHandleImpl* launchImpl(
		const std::string& command, 
		const ArgsImpl& args, 
		const std::string& initialDirectory,
		Pipe* inPipe, 
		Pipe* outPipe, 
		Pipe* errPipe,
		const EnvImpl& env);
	static void killImpl(ProcessHandleImpl& handle);
	static void killImpl(PIDImpl pid);
	static bool isRunningImpl(const ProcessHandleImpl& handle);
	static bool isRunningImpl(PIDImpl pid);
	static void requestTerminationImpl(PIDImpl pid);

private:
	static ProcessHandleImpl* launchByForkExecImpl(
		const std::string& command, 
		const ArgsImpl& args, 
		const std::string& initialDirectory,
		Pipe* inPipe, 
		Pipe* outPipe, 
		Pipe* errPipe,
		const EnvImpl& env);
};


} // namespace pi


#endif // PIL_Process_UNIX_INCLUDED
