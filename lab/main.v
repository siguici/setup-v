module main

fn welcome(name string) string {
	return 'Hello, ${name}. Welcome to V!'
}

fn main() {
	println(welcome('Sigui'))
}
