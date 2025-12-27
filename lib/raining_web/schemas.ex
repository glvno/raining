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

  defmodule DropletParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletParams",
      description: "Request schema for creating a droplet",
      type: :object,
      properties: %{
        content: %Schema{
          type: :string,
          description: "Text content of the droplet",
          minLength: 1,
          maxLength: 500
        },
        latitude: %Schema{
          type: :number,
          description: "Latitude coordinate",
          minimum: -90,
          maximum: 90,
          format: :float
        },
        longitude: %Schema{
          type: :number,
          description: "Longitude coordinate",
          minimum: -180,
          maximum: 180,
          format: :float
        }
      },
      required: [:content, :latitude, :longitude],
      example: %{
        "content" => "It's raining here!",
        "latitude" => 52.5,
        "longitude" => 13.4
      }
    })
  end

  defmodule Droplet do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Droplet",
      description: "A droplet (social post with geolocation)",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "Droplet ID"},
        content: %Schema{type: :string, description: "Text content"},
        latitude: %Schema{type: :number, description: "Latitude coordinate", format: :float},
        longitude: %Schema{type: :number, description: "Longitude coordinate", format: :float},
        user: User,
        inserted_at: %Schema{
          type: :string,
          description: "Creation timestamp",
          format: :"date-time"
        },
        updated_at: %Schema{
          type: :string,
          description: "Last update timestamp",
          format: :"date-time"
        }
      },
      required: [:id, :content, :latitude, :longitude, :user, :inserted_at, :updated_at],
      example: %{
        "id" => 1,
        "content" => "It's raining here!",
        "latitude" => 52.5,
        "longitude" => 13.4,
        "user" => %{
          "id" => 123,
          "email" => "joe@gmail.com"
        },
        "inserted_at" => "2024-01-15T12:34:55Z",
        "updated_at" => "2024-01-15T12:34:55Z"
      }
    })
  end

  defmodule DropletResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletResponse",
      description: "Response schema for single droplet",
      type: :object,
      properties: %{
        droplet: Droplet
      },
      example: %{
        "droplet" => %{
          "id" => 1,
          "content" => "It's raining here!",
          "latitude" => 52.5,
          "longitude" => 13.4,
          "user" => %{
            "id" => 123,
            "email" => "joe@gmail.com"
          },
          "inserted_at" => "2024-01-15T12:34:55Z",
          "updated_at" => "2024-01-15T12:34:55Z"
        }
      }
    })
  end

  defmodule DropletsResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletsResponse",
      description: "Response schema for droplet feed",
      type: :object,
      properties: %{
        droplets: %Schema{
          type: :array,
          items: Droplet,
          description: "Array of droplets in the feed"
        },
        count: %Schema{type: :integer, description: "Number of droplets in the feed"},
        time_window_hours: %Schema{
          type: :integer,
          description: "Time window in hours used for the feed"
        },
        message: %Schema{type: :string, description: "Optional message (e.g., 'Not raining')"}
      },
      required: [:droplets, :count],
      example: %{
        "droplets" => [
          %{
            "id" => 1,
            "content" => "It's raining here!",
            "latitude" => 52.5,
            "longitude" => 13.4,
            "user" => %{
              "id" => 123,
              "email" => "joe@gmail.com"
            },
            "inserted_at" => "2024-01-15T12:34:55Z",
            "updated_at" => "2024-01-15T12:34:55Z"
          }
        ],
        "count" => 1,
        "time_window_hours" => 2
      }
    })
  end
end
