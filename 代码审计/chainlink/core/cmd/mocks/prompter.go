// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import mock "github.com/stretchr/testify/mock"

// Prompter is an autogenerated mock type for the Prompter type
type Prompter struct {
	mock.Mock
}

type Prompter_Expecter struct {
	mock *mock.Mock
}

func (_m *Prompter) EXPECT() *Prompter_Expecter {
	return &Prompter_Expecter{mock: &_m.Mock}
}

// IsTerminal provides a mock function with no fields
func (_m *Prompter) IsTerminal() bool {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for IsTerminal")
	}

	var r0 bool
	if rf, ok := ret.Get(0).(func() bool); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(bool)
	}

	return r0
}

// Prompter_IsTerminal_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'IsTerminal'
type Prompter_IsTerminal_Call struct {
	*mock.Call
}

// IsTerminal is a helper method to define mock.On call
func (_e *Prompter_Expecter) IsTerminal() *Prompter_IsTerminal_Call {
	return &Prompter_IsTerminal_Call{Call: _e.mock.On("IsTerminal")}
}

func (_c *Prompter_IsTerminal_Call) Run(run func()) *Prompter_IsTerminal_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Prompter_IsTerminal_Call) Return(_a0 bool) *Prompter_IsTerminal_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Prompter_IsTerminal_Call) RunAndReturn(run func() bool) *Prompter_IsTerminal_Call {
	_c.Call.Return(run)
	return _c
}

// PasswordPrompt provides a mock function with given fields: _a0
func (_m *Prompter) PasswordPrompt(_a0 string) string {
	ret := _m.Called(_a0)

	if len(ret) == 0 {
		panic("no return value specified for PasswordPrompt")
	}

	var r0 string
	if rf, ok := ret.Get(0).(func(string) string); ok {
		r0 = rf(_a0)
	} else {
		r0 = ret.Get(0).(string)
	}

	return r0
}

// Prompter_PasswordPrompt_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'PasswordPrompt'
type Prompter_PasswordPrompt_Call struct {
	*mock.Call
}

// PasswordPrompt is a helper method to define mock.On call
//   - _a0 string
func (_e *Prompter_Expecter) PasswordPrompt(_a0 interface{}) *Prompter_PasswordPrompt_Call {
	return &Prompter_PasswordPrompt_Call{Call: _e.mock.On("PasswordPrompt", _a0)}
}

func (_c *Prompter_PasswordPrompt_Call) Run(run func(_a0 string)) *Prompter_PasswordPrompt_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string))
	})
	return _c
}

func (_c *Prompter_PasswordPrompt_Call) Return(_a0 string) *Prompter_PasswordPrompt_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Prompter_PasswordPrompt_Call) RunAndReturn(run func(string) string) *Prompter_PasswordPrompt_Call {
	_c.Call.Return(run)
	return _c
}

// Prompt provides a mock function with given fields: _a0
func (_m *Prompter) Prompt(_a0 string) string {
	ret := _m.Called(_a0)

	if len(ret) == 0 {
		panic("no return value specified for Prompt")
	}

	var r0 string
	if rf, ok := ret.Get(0).(func(string) string); ok {
		r0 = rf(_a0)
	} else {
		r0 = ret.Get(0).(string)
	}

	return r0
}

// Prompter_Prompt_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Prompt'
type Prompter_Prompt_Call struct {
	*mock.Call
}

// Prompt is a helper method to define mock.On call
//   - _a0 string
func (_e *Prompter_Expecter) Prompt(_a0 interface{}) *Prompter_Prompt_Call {
	return &Prompter_Prompt_Call{Call: _e.mock.On("Prompt", _a0)}
}

func (_c *Prompter_Prompt_Call) Run(run func(_a0 string)) *Prompter_Prompt_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string))
	})
	return _c
}

func (_c *Prompter_Prompt_Call) Return(_a0 string) *Prompter_Prompt_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Prompter_Prompt_Call) RunAndReturn(run func(string) string) *Prompter_Prompt_Call {
	_c.Call.Return(run)
	return _c
}

// NewPrompter creates a new instance of Prompter. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewPrompter(t interface {
	mock.TestingT
	Cleanup(func())
}) *Prompter {
	mock := &Prompter{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
