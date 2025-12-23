defmodule RainingWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule User do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User",
      description: "A user of the app",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "User ID"},
        email: %Schema{type: :string, description: "Email address", format: :email},
        confirmed_at: %Schema{
          type: :string,
          description: "Confirmation timestamp",
          format: :"date-time"
        },
        authenticated_at: %Schema{
          type: :string,
          description: "Auth timestamp",
          format: :"date-time"
        }
      },
      required: [:name, :email],
      example: %{
        "id" => 123,
        "email" => "joe@gmail.com",
        "confirmed_at" => "2017-09-12T12:34:55Z",
        "authenticated_at" => "2017-09-13T10:11:12Z"
      }
    })
  end

  defmodule UserRegistrationParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UserRegistrationParams",
      description: "Request schema for user registration",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email address", format: :email},
        password: %Schema{type: :string, description: "Password", format: :email}
      }
    })
  end

  defmodule UserResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UserResponse",
      description: "Response schema for single user",
      type: :object,
      properties: %{
        data: User
      },
      example: %{
        "data" => %{
          "id" => 123,
          "email" => "joe@gmail.com",
          "confirmed_at" => "2017-09-12T12:34:55Z",
          "authenticated_at" => "2017-09-13T10:11:12Z"
        }
      }
    })
  end
end
